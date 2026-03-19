import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some View {
        VStack(spacing: 0) {
            // 标签切换
            if debuggerService.isDebugging {
                DebugSidebarView()
            } else {
                ProjectSidebarView()
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// 非调试模式：项目/类浏览器
struct ProjectSidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "项目"

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                SidebarTabButton(title: "项目", selected: selectedTab == "项目") {
                    selectedTab = "项目"
                }
                SidebarTabButton(title: "类", selected: selectedTab == "类") {
                    selectedTab = "类"
                }
            }
            .background(Color(hex: "#2d2d30"))

            Divider().background(Color(hex: "#3e3e42"))

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if selectedTab == "项目" {
                        ProjectTreeView()
                    } else {
                        ClassBrowserView()
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ProjectTreeView: View {
    @EnvironmentObject var appState: AppState

    var projectName: String {
        if let path = appState.currentFilePath {
            return (path as NSString).deletingLastPathComponent.components(separatedBy: "/").last ?? "项目"
        }
        return "未命名项目"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#cccccc"))
                Text(projectName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#cccccc"))
            }

            if appState.currentFileName != "未保存.cpp" || appState.isModified {
                HStack(spacing: 4) {
                    Spacer().frame(width: 12)
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#cccccc"))
                    Text(appState.currentFileName)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#cccccc"))
                }
            }
        }
    }
}

struct ClassBrowserView: View {
    var body: some View {
        Text("（无类信息）")
            .font(.system(size: 12))
            .foregroundColor(Color(hex: "#858585"))
    }
}

// 调试模式：监视/局部/调用栈
struct DebugSidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService
    @State private var selectedTab: String = "监视"

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                SidebarTabButton(title: "监视", selected: selectedTab == "监视") {
                    selectedTab = "监视"
                }
                SidebarTabButton(title: "局部", selected: selectedTab == "局部") {
                    selectedTab = "局部"
                }
                SidebarTabButton(title: "栈", selected: selectedTab == "栈") {
                    selectedTab = "栈"
                }
            }
            .background(Color(hex: "#2d2d30"))

            Divider().background(Color(hex: "#3e3e42"))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if selectedTab == "监视" {
                        WatchView()
                    } else if selectedTab == "局部" {
                        LocalsView()
                    } else {
                        CallStackView()
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WatchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService
    @State private var newWatchExpression: String = ""
    @State private var isAddingWatch: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if debuggerService.watchVariables.isEmpty && !isAddingWatch {
                Text("（无监视）")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#858585"))
                    .padding(.top, 4)
            }

            ForEach(debuggerService.watchVariables) { variable in
                HStack {
                    Text(variable.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccccc"))
                    Spacer()
                    Text(variable.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#b5cea8"))
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button("删除") {
                        debuggerService.removeWatch(expression: variable.name)
                    }
                }
            }

            if isAddingWatch {
                HStack {
                    TextField("表达式", text: $newWatchExpression)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .onSubmit {
                            addWatch()
                        }
                    Button("添加") {
                        addWatch()
                    }
                    .font(.system(size: 11))
                    Button("取消") {
                        isAddingWatch = false
                        newWatchExpression = ""
                    }
                    .font(.system(size: 11))
                }
                .padding(.top, 4)
            }

            if !isAddingWatch {
                Button("+ 添加监视...") {
                    isAddingWatch = true
                }
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#007acc"))
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func addWatch() {
        let trimmed = newWatchExpression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        debuggerService.addWatch(expression: trimmed)
        newWatchExpression = ""
        isAddingWatch = false
    }
}

struct LocalsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if debuggerService.localVariables.isEmpty {
                Text("（无局部变量）")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#858585"))
                    .padding(.top, 4)
            }
            ForEach(debuggerService.localVariables, id: \.name) { variable in
                HStack {
                    Text(variable.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccccc"))
                    Spacer()
                    Text(variable.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#b5cea8"))
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct CallStackView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if debuggerService.callStack.isEmpty {
                Text("（无调用栈）")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#858585"))
                    .padding(.top, 4)
            }
            ForEach(debuggerService.callStack) { frame in
                HStack {
                    Text("#\(frame.level)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#858585"))
                        .frame(width: 24, alignment: .leading)
                    Text(frame.function)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccccc"))
                }
                .padding(.vertical, 1)
                .textSelection(.enabled)
            }
        }
    }
}

struct SidebarTabButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(selected ? .white : Color(hex: "#cccccc"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(selected ? Color(hex: "#1e1e1e") : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
