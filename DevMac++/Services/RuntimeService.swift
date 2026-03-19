import Foundation

class RuntimeService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var output: String = ""
    @Published var isFinished: Bool = false
    @Published var exitCode: Int32? = nil

    private var process: Process?
    private var outputHandle: FileHandle?
    private var inputHandle: FileHandle?

    func run(executable: String, workingDir: String? = nil) {
        guard !isRunning else { return }

        DispatchQueue.main.async {
            self.isRunning = true
            self.isFinished = false
            self.output = ""
            self.exitCode = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeProgram(executable: executable, workingDir: workingDir)
        }
    }

    private func executeProgram(executable: String, workingDir: String?) {
        let proc = Process()
        let outPipe = Pipe()
        let inPipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: executable)
        proc.standardOutput = outPipe
        proc.standardError = outPipe
        proc.standardInput = inPipe

        if let dir = workingDir {
            proc.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        self.process = proc
        self.inputHandle = inPipe.fileHandleForWriting

        // 非阻塞读取输出
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let chunk = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.output += chunk
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            outPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.isFinished = true
                self?.exitCode = proc.terminationStatus
                self?.output += "\n\n[程序已退出，退出码: \(proc.terminationStatus)]"
            }
        }

        do {
            try proc.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.output += "\n错误: \(error.localizedDescription)"
                self?.isRunning = false
                self?.isFinished = true
            }
        }
    }

    func sendLine(_ line: String) {
        guard isRunning, let input = inputHandle else { return }
        let data = (line + "\n").data(using: .utf8)!
        input.write(data)
    }

    func sendAll(_ text: String) {
        guard isRunning, let input = inputHandle else { return }
        let toSend = text.hasSuffix("\n") ? text : text + "\n"
        let data = toSend.data(using: .utf8)!
        input.write(data)
    }

    func stop() {
        process?.terminate()
        process = nil
        inputHandle = nil

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.output += "\n\n[已停止]"
        }
    }
}
