import Foundation
import Combine

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

    private var gdbProcess: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var commandQueue: [String] = []
    private var pendingCommands: [String: (Result<[String: Any], Error>) -> Void] = [:]
    private var sequenceNumber: Int = 0
    private var currentExecutable: String?
    private var buffer: String = ""

    var gdbPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gdb") {
            return "/opt/homebrew/bin/gdb"
        }
        return "gdb"
    }

    // MARK: - Public API

    func startDebug(executable: String, sourceFile: String, breakpoints: Set<Int>) async throws {
        guard !isDebugging else { return }

        currentExecutable = executable
        currentFile = sourceFile
        debuggerError = nil
        debugOutput = ""

        gdbProcess = Process()
        outputPipe = Pipe()
        inputPipe = Pipe()

        gdbProcess?.executableURL = URL(fileURLWithPath: gdbPath)
        gdbProcess?.arguments = ["-i", "mi", executable]
        gdbProcess?.standardOutput = outputPipe
        gdbProcess?.standardError = outputPipe
        gdbProcess?.standardInput = inputPipe

        setupOutputHandler()

        do {
            try gdbProcess?.run()
        } catch {
            throw DebugError.launchFailed(error.localizedDescription)
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        sendCommand("-gdb-set print sevenbit-strings off")
        sendCommand("-gdb-set charset UTF-8")
        sendCommand("-file-exec-and-symbols \(executable)")

        for line in breakpoints {
            _ = await sendCommandSync("-break-insert \(sourceFile):\(line)")
            debugOutput += "Breakpoint set at line \(line)\n"
        }

        _ = await sendCommandSync("-break-insert main")
        _ = await sendCommandSync("-exec-run")

        isDebugging = true
        isPaused = true
        debugOutput += "Debugging started: \(executable)\n"

        await refreshState()
    }

    func stopDebug() {
        guard isDebugging else { return }

        Task {
            _ = await sendCommandSync("-exec-abort")
        }

        gdbProcess?.terminate()
        gdbProcess = nil
        outputPipe = nil
        inputPipe = nil

        isDebugging = false
        isPaused = false
        currentLine = nil
        localVariables = []
        callStack = []
        debugOutput += "Debugging stopped.\n"
    }

    func stepInto() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-step")
        await refreshState()
    }

    func stepOver() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-next")
        await refreshState()
    }

    func stepOut() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-finish")
        await refreshState()
    }

    func continue_() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-continue")
        await refreshState()
    }

    func addWatch(expression: String) {
        guard !watchVariables.contains(where: { $0.name == expression }) else { return }
        watchVariables.append(WatchVariable(name: expression))

        Task {
            if isDebugging {
                let result = await sendCommandSync("-data-evaluate-expression \(expression)")
                if let value = result["value"] as? String {
                    updateWatchValue(expression: expression, value: value)
                }
            }
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
                    self?.handleGDBOutput(output)
                }
            }
        }

        gdbProcess?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.handleGDBTerminated()
            }
        }
    }

    private func handleGDBOutput(_ output: String) {
        buffer += output
        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""
        for line in lines.dropLast() {
            parseGDBLine(line)
        }
    }

    private func parseGDBLine(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        debugOutput += line + "\n"

        if line.hasPrefix("(gdb)") {
            processPendingAsync()
            return
        }

        if line.hasPrefix("^done") || line.hasPrefix("^running") ||
           line.hasPrefix("^stopped") || line.hasPrefix("=") {
            if let dict = parseMIResult(line) {
                handleAsyncMessage(dict, raw: line)
            }
        }
    }

    private func handleAsyncMessage(_ dict: [String: Any], raw: String) {
        if raw.hasPrefix("^stopped") {
            isPaused = true
            if let reason = dict["reason"] as? String {
                debuggerError = nil
                if reason == "exited" {
                    stopDebug()
                    return
                }
            }
            if let frame = dict["frame"] as? [String: Any] {
                if let file = frame["file"] as? String { currentFile = file }
                if let line = frame["line"] as? Int { currentLine = line }
            }
            Task { await refreshState() }
        }
    }

    private func refreshState() async {
        let localsResult = await sendCommandSync("-stack-list-locals 0")
        if let locals = localsResult["locals"] as? [[String: Any]] {
            localVariables = locals.compactMap { local -> (String, String)? in
                guard let name = local["name"] as? String else { return nil }
                let value = (local["value"] as? String) ?? "..."
                return (name, value)
            }
        }

        let stackResult = await sendCommandSync("-stack-list-frames")
        if let stack = stackResult["stack"] as? [[String: Any]] {
            callStack = stack.compactMap { frame -> StackFrame? in
                guard let level = frame["level"] as? Int,
                      let func_ = frame["func"] as? String else { return nil }
                let file = (frame["file"] as? String) ?? "?"
                let line = (frame["line"] as? Int) ?? 0
                return StackFrame(level: level, function: func_, file: file, line: line)
            }
        }

        for i in watchVariables.indices {
            let expr = watchVariables[i].name
            let result = await sendCommandSync("-data-evaluate-expression \(expr)")
            if let value = result["value"] as? String {
                watchVariables[i].value = value
            }
        }
    }

    func updateWatchValue(expression: String, value: String) {
        if let idx = watchVariables.firstIndex(where: { $0.name == expression }) {
            watchVariables[idx].value = value
        }
    }

    private func sendCommand(_ cmd: String) {
        guard let inputPipe = inputPipe else { return }
        let data = (cmd + "\n").data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(data)
    }

    private func sendCommandSync(_ cmd: String) async -> [String: Any] {
        sequenceNumber += 1
        let fullCmd = "-\(sequenceNumber)\(cmd)"
        sendCommand(fullCmd)

        return await withCheckedContinuation { continuation in
            let seq = "-\(sequenceNumber)"
            pendingCommands[seq] = { result in
                switch result {
                case .success(let dict): continuation.resume(returning: dict)
                case .failure: continuation.resume(returning: [:])
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if let pending = self.pendingCommands.removeValue(forKey: seq) {
                    pending(.success([:]))
                }
            }
        }
    }

    private func parseMIResult(_ line: String) -> [String: Any]? {
        guard let range = line.range(of: "{") else { return nil }
        let jsonStr = String(line[range.lowerBound...])
        var result: [String: Any] = [:]
        let pairs = jsonStr.components(separatedBy: ",")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"{ "))
                let value = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\" }"))
                result[key] = value
            }
        }
        return result
    }

    private func processPendingAsync() {
        // Process waiting command callbacks
    }

    private func handleGDBTerminated() {
        isDebugging = false
        isPaused = false
        debugOutput += "GDB process terminated.\n"
    }
}

enum DebugError: Error, LocalizedError {
    case launchFailed(String)
    case notCompiled
    case gdbNotSigned

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "GDB 启动失败: \(msg)"
        case .notCompiled: return "请先编译程序（带 -g 选项）"
        case .gdbNotSigned: return "GDB 未签名，无法调试进程"
        }
    }
}
