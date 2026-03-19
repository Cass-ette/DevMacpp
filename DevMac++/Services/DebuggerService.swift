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
    @Published var isWaitingForInput: Bool = false

    private var lldbProcess: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var buffer: String = ""
    private var recentOutput: String = ""
    private var isRefreshingState: Bool = false
    /// 暂存的断点变化（程序运行时用户toggle的断点，暂停时批量应用）
    private var pendingBreakpointChanges: [Int: Bool] = [:]  // line -> true=add, false=remove

    // MARK: - Public API

    func startDebug(executable: String, sourceFile: String, breakpoints: Set<Int>) async throws {
        // 先彻底停止旧会话（清管道、重置状态），再开新会话
        stopDebug()
        try await Task.sleep(nanoseconds: 200_000_000)

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
        lldbProcess?.arguments = ["--no-lldbinit", "--", executable]
        lldbProcess?.standardOutput = outputPipe
        lldbProcess?.standardError = outputPipe
        lldbProcess?.standardInput = inputPipe

        setupOutputHandler()

        do {
            try lldbProcess?.run()
        } catch {
            outputPipe?.fileHandleForReading.readabilityHandler = nil
            lldbProcess = nil
            outputPipe = nil
            inputPipe = nil
            throw DebugError.launchFailed(error.localizedDescription)
        }

        debugOutput += "LLDB 调试器已启动。\n"

        // 等待启动
        try await Task.sleep(nanoseconds: 300_000_000)

        // 设置源码映射："." -> 源码所在目录
        let srcDir = (sourceFile as NSString).deletingLastPathComponent
        let fileName = (sourceFile as NSString).lastPathComponent
        await sendCommand("settings set target.source-map . '\(srcDir)'")

        // 设置断点（用完整路径保证 LLDB 能找到源文件）
        for line in breakpoints.sorted() {
            _ = await sendCommand("breakpoint set --file '\(sourceFile)' --line \(line)")
            debugOutput += "断点已设置: 行 \(line)\n"
        }

        // 运行（不等待，程序在后台运行）
        sendCommandNoWait("run")

        isDebugging = true
        isPaused = false
        isWaitingForInput = false
    }

    func stopDebug() {
        guard isDebugging || lldbProcess != nil else { return }

        // 同步发送 kill 命令再清管道，避免 Task 异步时 pipes 已为 nil
        sendCommandNoWait("process kill")
        lldbProcess?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        lldbProcess = nil
        outputPipe = nil
        inputPipe = nil

        isDebugging = false
        isPaused = false
        isWaitingForInput = false
        currentLine = nil
        localVariables = []
        callStack = []
        watchVariables = []
        buffer = ""
        recentOutput = ""
        debugOutput += "调试已停止。\n"
    }

    func stepInto() async {
        guard isDebugging, isPaused else { return }
        isPaused = false
        sendCommandNoWait("thread step-in")
    }

    func removeBreakpoint(line: Int, file: String) async {
        guard isDebugging else { return }
        _ = await sendCommand("breakpoint delete \(line)")
        debugOutput += "断点已删除: 行 \(line)\n"
    }

    func stepOver() async {
        guard isDebugging, isPaused else { return }
        isPaused = false
        sendCommandNoWait("thread step-over")
    }

    func stepOut() async {
        guard isDebugging, isPaused else { return }
        isPaused = false
        sendCommandNoWait("thread step-out")
    }

    func continue_() async {
        guard isDebugging else { return }
        isWaitingForInput = false
        isPaused = false
        sendCommandNoWait("continue")
    }

    func addWatch(expression: String) {
        guard !watchVariables.contains(where: { $0.name == expression }) else { return }
        watchVariables.append(WatchVariable(name: expression, value: "..."))

        Task {
            let result = await sendCommandCapture("expression \(expression)")
            let value = parseVariableValue(result)
            if !value.isEmpty && value != "..." {
                updateWatchValue(expression: expression, value: value)
            }
        }
    }

    func removeWatch(expression: String) {
        watchVariables.removeAll { $0.name == expression }
    }

    func sendInput(_ text: String, autoContinue: Bool = false) {
        guard let inputPipe = inputPipe, isDebugging else { return }
        let line = text + "\n"
        if let data = line.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
        if autoContinue {
            sendCommandNoWait("continue")
        }
    }

    /// 暂存断点变化（程序运行时调用，暂停时批量应用）
    func queueBreakpointChange(line: Int, add: Bool) {
        pendingBreakpointChanges[line] = add
    }

    /// 立即应用暂存的断点变化（程序已暂停时调用）
    func applyPendingBreakpointChangesNow() async {
        await applyPendingBreakpointChanges()
    }

    private func applyPendingBreakpointChanges() async {
        guard !pendingBreakpointChanges.isEmpty, let file = currentFile else { return }

        // 删除时需要先查询 LLDB 获取断点 ID
        let listResult = await sendCommand("breakpoint list")
        for (line, add) in pendingBreakpointChanges {
            if add {
                _ = await sendCommand("breakpoint set --file '\(file)' --line \(line)")
            } else {
                // 查找该行对应的断点 ID（转义文件名避免 . 等字符被当通配符）
                let fileName = (file as NSString).lastPathComponent
                let escapedName = NSRegularExpression.escapedPattern(for: fileName)
                let deletePattern = "(\\d+).*\(escapedName):\\s*\(line)\\b"
                if let regex = try? NSRegularExpression(pattern: deletePattern),
                   let match = regex.firstMatch(in: listResult, range: NSRange(listResult.startIndex..., in: listResult)),
                   let idRange = Range(match.range(at: 1), in: listResult) {
                    let bpId = String(listResult[idRange])
                    _ = await sendCommand("breakpoint delete \(bpId)")
                }
            }
        }
        pendingBreakpointChanges.removeAll()
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
            // 维护最近输出窗口（用于跨行检测 stop reason）
            recentOutput += line + "\n"
            if recentOutput.count > 2000 {
                recentOutput = String(recentOutput.suffix(1000))
            }
            parseLLDBLine(line)
        }
    }

    private func parseLLDBLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // frame #0: 行（含 bt 输出中的 "* frame #0:"）：先解析位置，再过滤
        if trimmed.range(of: #"^\*? *frame #\d+:"#, options: .regularExpression) != nil {
            parseFrame(from: line)
            return
        }

        // stop reason 行：触发状态刷新（isRefreshingState 防止 bt 输出中的 stop reason 形成反馈循环）
        if !isRefreshingState &&
           (line.contains("stop reason = breakpoint") ||
            line.contains("stop reason = step") ||
            line.contains("stop reason = trace") ||
            line.contains("stop reason = signal") ||
            line.contains("stop reason = exception")) {
            isPaused = true
            isWaitingForInput = false
            Task { await refreshState() }
            return
        }

        // 过滤其余不显示的行
        if trimmed.hasPrefix("(lldb)") { return }
        if trimmed.range(of: #"^\([^)]+\) \$\d+ ="#, options: .regularExpression) != nil { return }
        if trimmed.hasPrefix("Breakpoint ") && (trimmed.contains(": where =") || trimmed.contains(" resolved")) { return }
        if trimmed.range(of: #"^\([^)]+\) \w+ ="#, options: .regularExpression) != nil { return }
        if trimmed.range(of: #"^\s*\d+\s"#, options: .regularExpression) != nil && !trimmed.hasPrefix("Process") { return }
        if trimmed == "^" || trimmed == "->" { return }
        if trimmed.hasPrefix("Current settings") { return }
        if trimmed.hasPrefix("target.source-map") { return }
        // 数组/结构体元素行: [0] = 1, [1] = {, 以及闭合的 }
        if trimmed.range(of: #"^\[\d+\]"#, options: .regularExpression) != nil { return }
        if trimmed == "}" || trimmed == "}," { return }

        debugOutput += line + "\n"

        // 检测程序已退出
        if line.contains("exited with status") || line.contains("exited normally") {
            isPaused = false
            isDebugging = false
            isWaitingForInput = false
            return
        }

        // 检测程序暂停（"Process stopped" 行，stop reason 在后续行处理）
        if line.contains("stopped") || line.contains("stopped due to") {
            isPaused = true
            isWaitingForInput = false
        }

        // 解析 "->" 行中的位置信息
        if line.contains("->") {
            parseFrame(from: line)
        }
    }

    private func parseFrame(from line: String) {
        // 格式: frame #0: 0x... module`function at file.cpp:26:18
        // 用 " at " 定位文件名部分，再取最后两个 :N 段
        let framePattern = #"frame #(\d+):.*? at (.+?):(\d+)(?::\d+)?"#
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
        guard !isRefreshingState else { return }
        isRefreshingState = true
        defer { isRefreshingState = false }

        // 应用暂存的断点变化
        await applyPendingBreakpointChanges()

        // 获取当前栈帧
        let btResult = await sendCommand("bt")
        parseBacktrace(from: btResult)

        // 获取局部变量
        let localsResult = await sendCommand("frame variable")
        parseLocals(from: localsResult)

        // 获取当前行
        let whereResult = await sendCommand("frame info")
        parseFrameInfo(from: whereResult)

        // 刷新监视变量（用 sendCommandCapture 拿增量输出，不污染 debugOutput）
        for i in watchVariables.indices {
            let expr = watchVariables[i].name
            let result = await sendCommandCapture("expression \(expr)")
            let value = parseVariableValue(result)
            if !value.isEmpty && value != "..." {
                watchVariables[i].value = value
            }
        }
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

        // 找 LLDB expression 结果行：形如 "(type) $N = ..." 或 "(type) name = ..."
        for (i, line) in lines.enumerated() {
            guard line.range(of: #"\([^)]+\).*= "#, options: .regularExpression) != nil else { continue }
            guard let eqRange = line.range(of: " = ", options: .backwards) else { continue }

            let value = String(line[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // 简单值，直接返回
            guard value.hasSuffix("{") else { return value.isEmpty ? "..." : value }

            // 复合类型（vector/struct/array），收集到配对的 }
            var parts = [value]
            var depth = 1
            for j in (i + 1)..<lines.count {
                let trimmed = lines[j].trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                for ch in trimmed { if ch == "{" { depth += 1 } else if ch == "}" { depth -= 1 } }
                parts.append(trimmed)
                if depth <= 0 { break }
            }
            return parts.joined(separator: " ")
        }
        return "..."
    }

    func updateWatchValue(expression: String, value: String) {
        if let idx = watchVariables.firstIndex(where: { $0.name == expression }) {
            watchVariables[idx].value = value
        }
    }

    func sendRawCommand(_ cmd: String) async -> String {
        guard let inputPipe = inputPipe else { return "" }
        let fullCmd = cmd + "\n"
        if let data = fullCmd.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        return buffer
    }

    /// 发送命令不等待响应（用于 run/continue，程序在后台运行）
    private func sendCommandNoWait(_ cmd: String) {
        guard let inputPipe = inputPipe else { return }
        let fullCmd = cmd + "\n"
        if let data = fullCmd.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
    }

    /// 发送命令并返回该命令产生的新输出（用于需要解析返回值的场景）
    private func sendCommandCapture(_ cmd: String) async -> String {
        guard let inputPipe = inputPipe else { return "" }
        let before = recentOutput.count
        let fullCmd = cmd + "\n"
        if let data = fullCmd.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard recentOutput.count > before else { return "" }
        return String(recentOutput.suffix(recentOutput.count - before))
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
        isWaitingForInput = false
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
