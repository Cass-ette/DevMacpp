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

struct DebuggerState {
    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentLine: Int? = nil
    var currentFile: String? = nil
    var reason: String = ""
}

enum DebugCommand {
    case start(executable: String)
    case stop
    case continue_
    case stepInto
    case stepOver
    case stepOut
    case setBreakpoint(line: Int, file: String)
    case deleteBreakpoint(line: Int, file: String)
    case addWatch(expression: String)
    case removeWatch(expression: String)
    case evaluate(expression: String)
    case stackListFrames
    case stackListLocals
}

enum GDBOutputType {
    case result(dict: [String: Any])
    case stream(type: String, content: String)
    case async(type: String, data: [String: Any])
    case done
    case error(message: String)
}
