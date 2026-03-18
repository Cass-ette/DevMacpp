import Foundation

struct CompileError: Identifiable {
    let id = UUID()
    let file: String
    let line: Int
    let column: Int
    let message: String
}

struct CompileResult {
    let success: Bool
    let output: String
    let errors: [CompileError]
    let executablePath: String?
}
