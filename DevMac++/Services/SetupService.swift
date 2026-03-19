import Foundation

class SetupService: ObservableObject {
    @Published var gccInstalled = false
    @Published var lldbInstalled = false
    @Published var showSetupGuide = false

    init() {
        checkEnvironment()
    }

    func checkEnvironment() {
        gccInstalled = checkCommand("g++")
        // LLDB 随 Xcode Command Line Tools 一起安装，检查 /usr/bin/lldb
        lldbInstalled = FileManager.default.fileExists(atPath: "/usr/bin/lldb")

        if !gccInstalled || !lldbInstalled {
            showSetupGuide = true
        }
    }

    private func checkCommand(_ cmd: String) -> Bool {
        let result = runCommand("/usr/bin/which", args: [cmd])
        return !result.isEmpty && result.contains("/")
    }

    private func runCommand(_ cmd: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
