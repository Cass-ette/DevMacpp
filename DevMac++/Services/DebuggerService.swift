import Foundation

@MainActor
class DebuggerService: ObservableObject {
    @Published var isDebugging: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentLine: Int? = nil
    @Published var currentFile: String? = nil
    @Published var localVariables: [(name: String, value: String)] = []
    @Published var watchVariables: [WatchVariable] = []
    @Published var callStack: [StackFrame] = []
    @Published var debugOutput: String = ""
    @Published var debuggerError: String? = nil

    private var lldbProcess: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var buffer: String = ""

    // MARK: - Public API

    func startDebug(executable: String, sourceFile: String, breakpoints: Set<Int>) async throws {
        guard !isDebugging else { return }

        currentLine = nil
        currentFile = sourceFile
        debuggerError = nil
        debugOutput = ""
        localVariables = []
        callStack = []

        lldbProcess = Process()
        outputPipe = Pipe()
        inputPipe = Pipe()

        lldbProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/lldb")
        lldbProcess?.arguments = ["--no-lldbinit", executable]
        lldbProcess?.standardOutput = outputPipe
        lldbProcess?.standardError = outputPipe
        lldbProcess?.standardInput = inputPipe

        setupOutputHandler()

        do {
            try lldbProcess?.run()
        } catch {
            throw DebugError.launchFailed(error.localizedDescription)
        }

        debugOutput += "LLDB 调试器已启动。\n"

        // 等待启动
        try await Task.sleep(nanoseconds: 300_000_000)

        // 设置断点
        for line in breakpoints.sorted() {
            await sendCommand("breakpoint set --line \(line)")
            debugOutput += "断点已设置: 行 \(line)\n"
        }

        // 设置源码目录
        let srcDir = (sourceFile as NSString).deletingLastPathComponent
        await sendCommand("settings set target.source-map . \"\(srcDir)\"")

        // 运行到断点或 main
        await sendCommand("breakpoint set --name main")
        await sendCommand("run")

        isDebugging = true
        isPaused = true

        await refreshState()
    }

    func stopDebug() {
        guard isDebugging else { return }

        Task {
            await sendCommand("process kill")
        }

        lldbProcess?.terminate()
        lldbProcess = nil
        outputPipe = nil
        inputPipe = nil

        isDebugging = false
        isPaused = false
        currentLine = nil
        localVariables = []
        callStack = []
        watchVariables = []
        debugOutput += "调试已停止。\n"
    }

    func stepInto() async {
        guard isDebugging else { return }
        await sendCommand("thread step-in")
        await refreshState()
    }

    func stepOver() async {
        guard isDebugging else { return }
        await sendCommand("thread step-over")
        await refreshState()
    }

    func stepOut() async {
        guard isDebugging else { return }
        await sendCommand("thread step-out")
        await refreshState()
    }

    func continue_() async {
        guard isDebugging else { return }
        await sendCommand("continue")
        await refreshState()
    }

    func addWatch(expression: String) {
        guard !watchVariables.contains(where: { $0.name == expression }) else { return }
        watchVariables.append(WatchVariable(name: expression, value: "..."))

        Task {
            let result = await sendCommand("frame variable \(expression)")
            let value = parseVariableValue(result)
            updateWatchValue(expression: expression, value: value)
        }
    }

    func removeWatch(expression: String) {
        watchVariables.removeAll { $0.name == expression }
    }

    // MARK: - Private

    private func setupOutputHandler() {
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.handleLLDBOutput(output)
                }
            }
        }

        lldbProcess?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.handleLLDBTerminated()
            }
        }
    }

    private func handleLLDBOutput(_ output: String) {
        buffer += output

        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""

        for line in lines.dropLast() {
            parseLLDBLine(line)
        }
    }

    private func parseLLDBLine(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        debugOutput += line + "\n"

        // 检测是否停止
        if line.contains("stopped") || line.contains("exited") || line.contains("stopped due to") {
            isPaused = true
            Task { await refreshState() }
        }

        // 解析当前帧信息
        if line.contains("->") || line.contains("frame #") {
            parseFrame(from: line)
        }
    }

    private func parseFrame(from line: String) {
        // 尝试解析 "frame #0: 0x... at xxx.cpp:5"
        let framePattern = #"frame #(\d+): 0x[0-9a-f]+ at (.+?):(\d+)"#
        if let regex = try? NSRegularExpression(pattern: framePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let fileRange = Range(match.range(at: 2), in: line),
               let lineRange = Range(match.range(at: 3), in: line) {
                let file = String(line[fileRange]).trimmingCharacters(in: .whitespaces)
                if let lineNum = Int(line[lineRange]) {
                    currentFile = file
                    currentLine = lineNum
                }
            }
        }

        // 尝试解析 "at xxx.cpp:5"
        let atPattern = #"at (.+?):(\d+)"#
        if currentLine == nil,
           let regex = try? NSRegularExpression(pattern: atPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let fileRange = Range(match.range(at: 1), in: line),
               let lineRange = Range(match.range(at: 2), in: line) {
                let file = String(line[fileRange]).trimmingCharacters(in: .whitespaces)
                if let lineNum = Int(line[lineRange]) {
                    currentFile = file
                    currentLine = lineNum
                }
            }
        }
    }

    private func refreshState() async {
        // 获取当前栈帧
        let btResult = await sendCommand("bt")
        parseBacktrace(from: btResult)

        // 获取局部变量
        let localsResult = await sendCommand("frame variable")
        parseLocals(from: localsResult)

        // 获取当前行
        let whereResult = await sendCommand("frame info")
        parseFrameInfo(from: whereResult)
    }

    private func parseBacktrace(from output: String) {
        var frames: [StackFrame] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // frame #0: 0x... at xxx.cpp:5
            let pattern = #"frame #(\d+): 0x[0-9a-f]+ at (.+?):(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let levelRange = Range(match.range(at: 1), in: line),
                   let fileRange = Range(match.range(at: 2), in: line),
                   let lineRange = Range(match.range(at: 3), in: line) {
                    let level = Int(line[levelRange]) ?? 0
                    let file = String(line[fileRange]).trimmingCharacters(in: .whitespaces)
                    let lineNum = Int(line[lineRange]) ?? 0
                    frames.append(StackFrame(level: level, function: file, file: file, line: lineNum))
                }
            }
        }

        if !frames.isEmpty {
            callStack = frames
        }
    }

    private func parseLocals(from output: String) {
        var locals: [(name: String, value: String)] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("(") || trimmed == "no variables" { continue }

            // "x = 10" 或 "(int) x = 10"
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let namePart = parts[0].trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"\(.*\)"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                let valuePart = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)

                if !namePart.isEmpty && !namePart.hasPrefix("[") && namePart.hasPrefix(" ") == false {
                    locals.append((name: namePart, value: valuePart))
                }
            }
        }

        if !locals.isEmpty {
            localVariables = locals
        }
    }

    private func parseFrameInfo(from output: String) {
        // "-> source.cpp:5" 或 "frame #0"
        if let lineMatch = output.range(of: #":\d+$"#, options: .regularExpression) {
            let beforeLine = output[..<lineMatch.lowerBound]
            if let fileMatch = beforeLine.range(of: #"[\w/]+\.\w+$"#, options: .regularExpression) {
                let file = String(output[fileMatch])
                let lineStr = String(output[lineMatch]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                if let lineNum = Int(lineStr) {
                    currentFile = file
                    currentLine = lineNum
                }
            }
        }
    }

    private func parseVariableValue(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("=") {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    return parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return "..."
    }

    func updateWatchValue(expression: String, value: String) {
        if let idx = watchVariables.firstIndex(where: { $0.name == expression }) {
            watchVariables[idx].value = value
        }
    }

    private func sendCommand(_ cmd: String) async -> String {
        guard let inputPipe = inputPipe else { return "" }

        let fullCmd = cmd + "\n"
        let data = fullCmd.data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(data)

        // 等待一小段时间让输出返回
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 从 buffer 中提取相关行
        return buffer
    }

    private func handleLLDBTerminated() {
        isDebugging = false
        isPaused = false
        debugOutput += "\n[调试器已退出]\n"
    }
}

enum DebugError: Error, LocalizedError {
    case launchFailed(String)
    case notCompiled
    case debuggerNotAvailable

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "调试器启动失败: \(msg)"
        case .notCompiled: return "请先编译程序（带 -g 选项）"
        case .debuggerNotAvailable: return "调试器不可用"
        }
    }
}
