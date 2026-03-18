import SwiftUI
import Combine

struct CursorPosition {
    var line: Int = 1
    var column: Int = 1
}

@MainActor
class AppState: ObservableObject {
    // 编辑器状态
    @Published var currentFilePath: String? = nil
    @Published var currentFileName: String = "未保存.cpp"
    @Published var fileContent: String = ""
    @Published var cursorPosition: CursorPosition = CursorPosition()
    @Published var isModified: Bool = false
    @Published var fileSize: Int = 0
    @Published var insertMode: InsertMode = .insert
    @Published var editorReady: Bool = false

    // 编译状态
    @Published var isCompiling: Bool = false
    @Published var compileLog: String = ""
    @Published var compileOutput: String = ""
    @Published var compileErrors: [CompileError] = []
    @Published var compileSuccess: Bool = false
    @Published var lastCompiledPath: String? = nil
    @Published var lastCompiledWithDebug: Bool = false

    // 调试状态
    @Published var isDebugging: Bool = false
    @Published var breakpoints: Set<Int> = []
    @Published var currentDebugLine: Int? = nil
    @Published var watchVariables: [String] = []
    @Published var localVariables: [(name: String, value: String)] = []
    @Published var callStack: [String] = []

    // UI 状态
    @Published var selectedBottomTab: BottomTab = .compileLog
    @Published var selectedSidebarTab: SidebarTab = .project
    @Published var sidebarWidth: CGFloat = 200
    @Published var bottomPanelHeight: CGFloat = 150
}
