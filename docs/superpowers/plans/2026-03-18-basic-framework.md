# 基础框架实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 DevMac++ 的基础 SwiftUI 窗口框架，包括菜单栏、工具栏、侧边栏、底部面板和状态栏

**Architecture:** 使用 SwiftUI 构建主窗口结构，采用 MVVM 模式，AppState 作为全局状态管理，各个 View 组件独立且可复用

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 14.0+

---

## 文件结构

```
DevMac++/
├── DevMac++.xcodeproj
├── DevMac++/
│   ├── App/
│   │   ├── DevMacApp.swift          # 应用入口
│   │   └── AppState.swift           # 全局状态管理
│   ├── Views/
│   │   ├── ContentView.swift        # 主窗口容器
│   │   ├── ToolbarView.swift        # 工具栏（两行）
│   │   ├── SidebarView.swift        # 左侧边栏
│   │   ├── BottomPanelView.swift    # 底部面板
│   │   └── StatusBarView.swift      # 状态栏
│   ├── Models/
│   │   └── Enums.swift              # 枚举定义
│   └── Info.plist
└── DevMacTests/
    └── DevMacTests.swift
```


## Chunk 1: Xcode 项目初始化 + AppState

### Task 1: 创建 Xcode 项目

**Files:**
- Create: `DevMac++.xcodeproj`
- Create: `DevMac++/App/DevMacApp.swift`
- Create: `DevMac++/App/AppState.swift`
- Create: `DevMac++/Models/Enums.swift`

- [ ] **Step 1: 创建 Xcode 项目**

打开 Xcode → File → New → Project → macOS → App
- Product Name: `DevMac++`
- Bundle Identifier: `com.devmacpp.app`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: macOS 14.0
- 取消勾选 "Include Tests"（先不加测试）

- [ ] **Step 2: 创建 Enums.swift**

创建 `DevMac++/Models/Enums.swift`：

```swift
import Foundation

enum BottomTab: String, CaseIterable {
    case compileLog = "编译日志"
    case compileResult = "编译结果"
    case debug = "调试"
    case findResults = "查找结果"
}

enum SidebarTab: String, CaseIterable {
    case project = "项目"
    case classes = "类"
    case watch = "监视"
    case locals = "局部"
    case callStack = "栈"
}

enum InsertMode: String {
    case insert = "插入"
    case overwrite = "覆盖"
}
```

- [ ] **Step 3: 创建 AppState.swift**

创建 `DevMac++/App/AppState.swift`：

```swift
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

    // 编译状态
    @Published var isCompiling: Bool = false
    @Published var compileLog: String = ""
    @Published var compileOutput: String = ""
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
```

- [ ] **Step 4: 更新 DevMacApp.swift**

注意：`AppMenuCommands` 在 Task 7 才完整实现，这里先用空 stub，Task 7 完成后替换。

```swift
import SwiftUI

@main
struct DevMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        // AppMenuCommands 在 Task 7 添加
    }
}
```

- [ ] **Step 5: 构建验证**

在 Xcode 中按 Cmd+B 构建，确认无编译错误。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: init Xcode project with AppState and enums"
```

---

### Task 2: 主窗口 ContentView

**Files:**
- Create: `DevMac++/Views/ContentView.swift`

- [ ] **Step 1: 创建 ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            ToolbarView()
                .background(.ultraThinMaterial)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 主内容区（侧边栏 + 编辑器）
            HSplitView {
                SidebarView()
                    .frame(minWidth: 150, idealWidth: appState.sidebarWidth, maxWidth: 400)
                    .background(.ultraThinMaterial)

                // 编辑器占位（Plan 2 实现）
                EditorPlaceholderView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 底部面板
            BottomPanelView()
                .frame(height: appState.bottomPanelHeight)
                .background(.ultraThinMaterial)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 状态栏
            StatusBarView()
                .background(.ultraThinMaterial)
        }
        .background(Color(hex: "#1e1e1e"))
        .preferredColorScheme(.dark)
    }
}

// 编辑器占位视图（Plan 2 替换）
struct EditorPlaceholderView: View {
    var body: some View {
        ZStack {
            Color(hex: "#1e1e1e")
            Text("编辑器加载中...")
                .foregroundColor(Color(hex: "#858585"))
                .font(.system(size: 13, design: .monospaced))
        }
    }
}

// Color hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ContentView with main window layout"
```


---

### Task 3: 工具栏

**Files:**
- Create: `DevMac++/Views/ToolbarView.swift`

- [ ] **Step 1: 创建 ToolbarView.swift**

```swift
import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 第一行：文件操作 + 编辑操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "doc", tooltip: "新建 (Cmd+N)") {}
                ToolbarButton(icon: "folder", tooltip: "打开 (Cmd+O)") {}
                ToolbarButton(icon: "square.and.arrow.down", tooltip: "保存 (Cmd+S)") {}
                ToolbarButton(icon: "square.and.arrow.down.on.square", tooltip: "另存为 (Cmd+Shift+S)") {}
                ToolbarButton(icon: "xmark", tooltip: "关闭 (Cmd+W)") {}

                ToolbarDivider()

                ToolbarButton(icon: "printer", tooltip: "打印") {}

                ToolbarDivider()

                ToolbarButton(icon: "scissors", tooltip: "剪切 (Cmd+X)") {}
                ToolbarButton(icon: "doc.on.doc", tooltip: "复制 (Cmd+C)") {}
                ToolbarButton(icon: "doc.on.clipboard", tooltip: "粘贴 (Cmd+V)") {}

                ToolbarDivider()

                ToolbarButton(icon: "arrow.uturn.backward", tooltip: "撤销 (Cmd+Z)") {}
                ToolbarButton(icon: "arrow.uturn.forward", tooltip: "重做 (Cmd+Shift+Z)") {}

                ToolbarDivider()

                ToolbarButton(icon: "magnifyingglass", tooltip: "查找 (Cmd+F)") {}
                ToolbarButton(icon: "arrow.left.arrow.right", tooltip: "替换 (Cmd+H)") {}

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 第二行：编译 + 调试操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "hammer", tooltip: "编译 (Cmd+F11)") {}
                ToolbarButton(icon: "play", tooltip: "运行 (Cmd+F10)", tint: Color(hex: "#4caf50")) {}
                ToolbarButton(icon: "play.fill", tooltip: "编译运行 (Cmd+F9)", tint: Color(hex: "#ff9800")) {}
                ToolbarButton(icon: "arrow.clockwise", tooltip: "重新编译") {}
                ToolbarButton(icon: "trash", tooltip: "清理") {}

                ToolbarDivider()

                ToolbarButton(icon: "ant", tooltip: "调试 (Cmd+F8)", tint: Color(hex: "#2196f3")) {}
                ToolbarButton(icon: "pause", tooltip: "暂停") {}
                ToolbarButton(icon: "stop", tooltip: "停止 (Cmd+F2)") {}
                ToolbarButton(icon: "arrow.down.to.line", tooltip: "单步进入 (Cmd+F11)") {}
                ToolbarButton(icon: "arrow.right.to.line", tooltip: "单步跳过 (Cmd+F10)") {}
                ToolbarButton(icon: "arrow.up.to.line", tooltip: "单步跳出 (Cmd+Shift+F11)") {}

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var tint: Color = Color(hex: "#cccccc")
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
    }
}
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误，运行 Cmd+R 查看工具栏外观。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add two-row toolbar with SF Symbols icons"
```

---

### Task 4: 左侧边栏

**Files:**
- Create: `DevMac++/Views/SidebarView.swift`

- [ ] **Step 1: 创建 SidebarView.swift**

```swift
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 标签切换
            if appState.isDebugging {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#cccccc"))
                Text("未命名项目")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#cccccc"))
            }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(appState.watchVariables, id: \.self) { variable in
                HStack {
                    Text(variable)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccccc"))
                    Spacer()
                    Text("...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#858585"))
                }
                .padding(.vertical, 2)
            }
            Button("+ 添加监视...") {
                // Plan 4 实现
            }
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "#007acc"))
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

struct LocalsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(appState.localVariables, id: \.name) { variable in
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(appState.callStack, id: \.self) { frame in
                Text(frame)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#cccccc"))
                    .padding(.vertical, 2)
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
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add sidebar with project browser and debug panels"
```


---

### Task 5: 底部面板

**Files:**
- Create: `DevMac++/Views/BottomPanelView.swift`

- [ ] **Step 1: 创建 BottomPanelView.swift**

```swift
import SwiftUI

struct BottomPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                ForEach(BottomTab.allCases, id: \.self) { tab in
                    BottomTabButton(
                        title: tab.rawValue,
                        selected: appState.selectedBottomTab == tab
                    ) {
                        appState.selectedBottomTab = tab
                    }
                }
                Spacer()
            }
            .background(Color(hex: "#2d2d30"))

            Divider().background(Color(hex: "#3e3e42"))

            // 内容区
            ScrollView {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        switch appState.selectedBottomTab {
                        case .compileLog:
                            Text(appState.compileLog.isEmpty ? "就绪" : appState.compileLog)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#cccccc"))
                        case .compileResult:
                            Text(appState.compileOutput.isEmpty ? "" : appState.compileOutput)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#cccccc"))
                        case .debug:
                            Text("调试输出将显示在这里")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#858585"))
                        case .findResults:
                            Text("查找结果将显示在这里")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#858585"))
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#252526"))
        }
    }
}

struct BottomTabButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(selected ? .white : Color(hex: "#cccccc"))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? Color(hex: "#1e1e1e") : Color.clear)
                .overlay(
                    Rectangle()
                        .fill(selected ? Color(hex: "#007acc") : Color.clear)
                        .frame(height: 2),
                    alignment: .top
                )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add bottom panel with four tabs"
```

---

### Task 6: 状态栏

**Files:**
- Create: `DevMac++/Views/StatusBarView.swift`

- [ ] **Step 1: 创建 StatusBarView.swift**

```swift
import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var fileSizeString: String {
        let bytes = appState.fileSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("第 \(appState.cursorPosition.line) 行，第 \(appState.cursorPosition.column) 列")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text(appState.insertMode.rawValue)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text(fileSizeString)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text("C++")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color(hex: "#007acc").opacity(0.15))
    }
}
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add status bar with cursor position and file info"
```


---

## Chunk 2: 菜单栏 + 文件标签栏

### Task 7: 菜单栏

**Files:**
- Create: `DevMac++/Views/AppMenuCommands.swift`

- [ ] **Step 1: 创建 AppMenuCommands.swift**

```swift
import SwiftUI

struct AppMenuCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // 文件菜单
        CommandMenu("文件") {
            Button("新建") {}
                .keyboardShortcut("n", modifiers: .command)
            Button("打开...") {}
                .keyboardShortcut("o", modifiers: .command)
            Divider()
            Button("保存") {}
                .keyboardShortcut("s", modifiers: .command)
            Button("另存为...") {}
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("关闭") {}
                .keyboardShortcut("w", modifiers: .command)
        }

        // 编辑菜单（替换默认）
        CommandGroup(replacing: .undoRedo) {
            Button("撤销") {}
                .keyboardShortcut("z", modifiers: .command)
            Button("重做") {}
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        // 搜索菜单
        CommandMenu("搜索") {
            Button("查找...") {}
                .keyboardShortcut("f", modifiers: .command)
            Button("替换...") {}
                .keyboardShortcut("h", modifiers: .command)
            Button("跳转到行...") {}
                .keyboardShortcut("g", modifiers: .command)
        }

        // 执行菜单
        CommandMenu("执行") {
            Button("编译") {}
                .keyboardShortcut(.f11, modifiers: .command)
            Button("运行") {}
                .keyboardShortcut(.f10, modifiers: .command)
            Button("编译运行") {}
                .keyboardShortcut(.f9, modifiers: .command)
            Divider()
            Button("调试") {}
                .keyboardShortcut(.f8, modifiers: .command)
            Button("停止调试") {}
                .keyboardShortcut(.f2, modifiers: .command)
            Divider()
            Button("切换断点") {}
                .keyboardShortcut(.f5, modifiers: .command)
        }

        // 工具菜单
        CommandMenu("工具") {
            Button("编译器选项...") {}
            Button("编辑器选项...") {}
            Divider()
            Button("代码模板管理...") {}
        }

        // 帮助菜单（追加到默认）
        CommandGroup(after: .help) {
            Button("C/C++ 参考手册") {}
        }
    }
}
```

- [ ] **Step 2: 构建验证**

Cmd+B，运行 Cmd+R，确认菜单栏显示正确的菜单项。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add menu bar with all Dev-C++ menus"
```

---

### Task 8: 文件标签栏

**Files:**
- Create: `DevMac++/Views/FileTabBarView.swift`
- Modify: `DevMac++/Views/ContentView.swift`

- [ ] **Step 1: 创建 FileTabBarView.swift**

```swift
import SwiftUI

struct FileTabBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            FileTabItem(
                fileName: appState.currentFileName,
                isModified: appState.isModified
            ) {
                // 关闭文件（Plan 2 实现）
            }
            Spacer()
        }
        .background(Color(hex: "#2d2d30"))
        .frame(height: 30)
    }
}

struct FileTabItem: View {
    let fileName: String
    let isModified: Bool
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 修改标记圆点
            if isModified {
                Circle()
                    .fill(Color(hex: "#cccccc"))
                    .frame(width: 6, height: 6)
            }

            Text(fileName)
                .font(.system(size: 12))
                .foregroundColor(.white)

            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#cccccc"))
                    .frame(width: 14, height: 14)
                    .background(isHovered ? Color.white.opacity(0.15) : Color.clear)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "#1e1e1e"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "#007acc"))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
```

- [ ] **Step 2: 更新 ContentView.swift，在编辑器区域上方加入标签栏**

在 `EditorPlaceholderView` 上方插入 `FileTabBarView`：

```swift
// 编辑器区域（侧边栏右侧）
VStack(spacing: 0) {
    FileTabBarView()
    Divider().background(Color(hex: "#3e3e42"))
    EditorPlaceholderView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

- [ ] **Step 3: 构建验证**

Cmd+B，运行 Cmd+R，确认文件标签栏显示正确，圆点在 `isModified = true` 时出现。

- [ ] **Step 4: 测试修改标记**

在 Xcode 的 Debug 控制台临时执行：
```swift
appState.isModified = true
```
确认标签上出现圆点。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add file tab bar with unsaved indicator dot"
```


---

## Chunk 3: 可调整面板大小 + 整体集成测试

### Task 9: 可拖拽调整面板大小

**Files:**
- Create: `DevMac++/Views/ResizableDivider.swift`
- Modify: `DevMac++/Views/ContentView.swift`

- [ ] **Step 1: 创建 ResizableDivider.swift**

```swift
import SwiftUI

// 垂直分割线（左右拖拽）
struct VerticalResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(width: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width == value.translation.width {
                            // 使用起始宽度 + 总偏移，避免累积误差
                            let newWidth = dragStartWidth + value.translation.width
                            width = min(max(newWidth, minWidth), maxWidth)
                        }
                    }
                    .onEnded { _ in
                        dragStartWidth = width
                    }
            )
            .onAppear { dragStartWidth = width }
    }
}

// 水平分割线（上下拖拽）
struct HorizontalResizableDivider: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var dragStartHeight: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(height: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = dragStartHeight - value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        dragStartHeight = height
                    }
            )
            .onAppear { dragStartHeight = height }
    }
}
```

- [ ] **Step 2: 更新 ContentView.swift 使用可拖拽分割线**

将 `ContentView` 中的 `HSplitView` 替换为手动布局：

```swift
var body: some View {
    VStack(spacing: 0) {
        ToolbarView()
            .background(.ultraThinMaterial)

        Divider().background(Color(hex: "#3e3e42"))

        // 主内容区
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: appState.sidebarWidth)
                .background(.ultraThinMaterial)

            VerticalResizableDivider(
                width: $appState.sidebarWidth,
                minWidth: 150,
                maxWidth: 400
            )

            VStack(spacing: 0) {
                FileTabBarView()
                Divider().background(Color(hex: "#3e3e42"))
                EditorPlaceholderView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        HorizontalResizableDivider(
            height: $appState.bottomPanelHeight,
            minHeight: 80,
            maxHeight: 400
        )

        BottomPanelView()
            .frame(height: appState.bottomPanelHeight)
            .background(.ultraThinMaterial)

        Divider().background(Color(hex: "#3e3e42"))

        StatusBarView()
            .background(.ultraThinMaterial)
    }
    .background(Color(hex: "#1e1e1e"))
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: 构建验证**

Cmd+B，运行 Cmd+R，拖拽侧边栏和底部面板的分割线，确认可以调整大小。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add resizable sidebar and bottom panel dividers"
```

---

### Task 10: 整体集成验证

**Files:** 无新文件

- [ ] **Step 1: 运行应用**

Cmd+R 运行应用，检查以下内容：

1. 窗口正常显示，最小尺寸 800x600
2. 菜单栏显示：文件/编辑/搜索/执行/工具/窗口/帮助
3. 工具栏两行，图标正常显示
4. 左侧边栏显示"项目"和"类"标签
5. 文件标签栏显示"未保存.cpp"
6. 底部面板显示四个标签页
7. 状态栏显示"第 1 行，第 1 列 | 插入 | 0 B | C++"
8. 侧边栏和底部面板可拖拽调整大小
9. 整体深色主题，毛玻璃效果正常

- [ ] **Step 2: 验证调试模式切换**

在 Xcode Debug 控制台临时设置：
```swift
// 在 AppState 中临时添加测试代码
appState.isDebugging = true
appState.watchVariables = ["n", "arr[0]"]
appState.localVariables = [("i", "0"), ("sum", "42")]
appState.callStack = ["main() at line 15", "solve() at line 8"]
```
确认左侧边栏切换为调试面板，显示监视/局部/栈三个标签。

- [ ] **Step 3: 最终 Commit**

```bash
git add -A
git commit -m "feat: complete basic framework - window layout, toolbar, sidebar, panels"
git push
```

---

## 完成标准

Plan 1 完成后，应用应该：

- [ ] 窗口正常启动，布局与 Dev-C++ 5.11 一致
- [ ] 菜单栏包含所有原版菜单项
- [ ] 工具栏两行，所有按钮使用 SF Symbols 图标（无 emoji）
- [ ] 左侧边栏在非调试/调试模式下正确切换
- [ ] 文件标签栏显示文件名和修改圆点
- [ ] 底部面板四个标签页可切换
- [ ] 状态栏显示行列号、插入模式、文件大小
- [ ] 侧边栏和底部面板可拖拽调整大小
- [ ] 整体深色主题 + 毛玻璃效果
- [ ] 代码推送到 GitHub

**下一步：** Plan 2 - Monaco Editor 集成
