import Foundation

class CompilerService: ObservableObject {
    @Published var isCompiling = false
    @Published var compileLog = ""
    @Published var lastResult: CompileResult?

    // GCC 路径
    var gccPath: String {
        let fm = FileManager.default
        let brewBin = "/opt/homebrew/bin"

        // 优先使用 Homebrew 的 g++ 版本
        if fm.fileExists(atPath: "\(brewBin)/g++-14") {
            return "\(brewBin)/g++-14"
        } else if fm.fileExists(atPath: "\(brewBin)/g++-13") {
            return "\(brewBin)/g++-13"
        } else if fm.fileExists(atPath: "\(brewBin)/g++") {
            return "\(brewBin)/g++"
        }
        // 回退到系统 clang 的 g++
        return "/usr/bin/g++"
    }

    @MainActor
    func compile(filePath: String, withDebug: Bool = false, options: CompilerOptions = CompilerOptions()) async throws -> CompileResult {
        isCompiling = true
        defer { isCompiling = false }

        let outputPath = (filePath as NSString).deletingPathExtension + "_run"
        var args = options.toArguments()
        if withDebug {
            args.append(contentsOf: ["-g", "-O0", "-fno-inline"])
        }
        args.append(contentsOf: ["-o", outputPath, filePath])

        let header = "=== 编译信息 ===\n编译器: \(gccPath)\n命令: \(gccPath) \(args.joined(separator: " "))\n\n=== 编译输出 ===\n"

        let result = try await runProcess(executable: gccPath, arguments: args)

        let errors = parseErrors(result.output, filePath: filePath)
        let success = result.returnCode == 0

        compileLog = header + result.output + "\n"
        if success {
            compileLog += "\n✅ 编译成功！"
        } else {
            compileLog += "\n❌ 编译失败。"
        }

        let compileResult = CompileResult(
            success: success,
            output: compileLog,
            errors: errors,
            executablePath: success ? outputPath : nil
        )

        lastResult = compileResult
        return compileResult
    }

    @MainActor
    func compileOnly(filePath: String) async throws -> CompileResult {
        return try await compile(filePath: filePath, withDebug: false)
    }

    @MainActor
    func compileForDebug(filePath: String) async throws -> CompileResult {
        return try await compile(filePath: filePath, withDebug: true)
    }

    /// 清理：删除当前源文件对应的可执行文件
    @MainActor
    func clean(filePath: String) -> String {
        let exePath = (filePath as NSString).deletingPathExtension + "_run"
        let fm = FileManager.default
        if fm.fileExists(atPath: exePath) {
            do {
                try fm.removeItem(atPath: exePath)
                return "已清理: \(exePath)"
            } catch {
                return "清理失败: \(error.localizedDescription)"
            }
        }
        return "无编译产物可清理"
    }

    private func runProcess(executable: String, arguments: [String]) async throws -> (output: String, returnCode: Int32) {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var outputData = Data()
            var errorData = Data()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outputData.append(data) }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { errorData.append(data) }
            }

            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                let combined = output + (errorOutput.isEmpty ? "" : "\n" + errorOutput)
                continuation.resume(returning: (combined, process.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseErrors(_ output: String, filePath: String) -> [CompileError] {
        var errors: [CompileError] = []
        let pattern = #"(.+?):(\d+):(\d+):\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return errors }
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let fileRange = Range(match.range(at: 1), in: line),
                   let lineRange = Range(match.range(at: 2), in: line),
                   let colRange = Range(match.range(at: 3), in: line),
                   let msgRange = Range(match.range(at: 4), in: line) {
                    let file = String(line[fileRange])
                    let lineNum = Int(line[lineRange]) ?? 0
                    let column = Int(line[colRange]) ?? 0
                    let message = String(line[msgRange])
                    errors.append(CompileError(file: file, line: lineNum, column: column, message: message))
                }
            }
        }
        return errors
    }
}
