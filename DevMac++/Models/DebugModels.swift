import Foundation

struct StackFrame: Identifiable {
    let id = UUID()
    let level: Int
    let function: String
    let file: String
    let line: Int
    var description: String { "\(function) at \(file):\(line)" }
}

struct WatchVariable: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var value: String = "..."
}

