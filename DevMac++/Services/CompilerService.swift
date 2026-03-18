import Foundation

class CompilerService: ObservableObject {
    @Published var isCompiling = false
    @Published var compileLog = ""
    @Published var lastResult: CompileResult?

    // GCC 路径
    var gccPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/g++-13") {
            return "/opt/homebrew/bin/g++-13"
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/g++") {
            return "/opt/homebrew/bin/g++"
        }
        return "g++"
    }

    var gdbPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gdb") {
            return "/opt/homebrew/bin/gdb"
        }
        return "gdb"
    }

    @MainActor
    func compile(filePath: String, withDebug: Bool = false, options: CompilerOptions = CompilerOptions()) async throws -> CompileResult {
        isCompiling = true
        defer { isCompiling = false }

        let outputPath = (filePath as NSString).deletingPathExtension + "_run"
        var args = options.toArguments()
        if withDebug {
            args.append("-g")
        }
        args.append(contentsOf: ["-o", outputPath, filePath])

        compileLog = "Compiling \(filePath)...\n"
        compileLog += "Compiler: \(gccPath)\n"
        compileLog += "Command: g++ \(args.joined(separator: " "))\n\n"

        let result = try await runProcess(executable: gccPath, arguments: args)
        compileLog += result.output

        let errors = parseErrors(result.output, filePath: filePath)
        let success = result.returnCode == 0

        if success {
            compileLog += "\nCompilation successful."
        } else {
            compileLog += "\nCompilation failed."
        }

        let compileResult = CompileResult(
            success: success,
            output: result.output,
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
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    let file = String(line[Range(match.range(at: 1), in: line)!])
                    let lineNum = Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                    let column = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
                    let message = String(line[Range(match.range(at: 4), in: line)!])
                    errors.append(CompileError(file: file, line: lineNum, column: column, message: message))
                }
            }
        }
        return errors
    }
}
