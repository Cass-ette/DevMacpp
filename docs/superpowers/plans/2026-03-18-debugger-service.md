# 调试器服务实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整 GDB 调试功能：启动调试、单步执行、断点管理、变量监视、调用栈显示、当前行高亮

**Architecture:** GDB/MI 协议通过 Swift Process 双向通信，子进程 stdout/stderr 实时流式读取。GDB 进程常驻，命令发送与输出解析在同一进程内完成。调试面板通过 AppState 与 MonacoEditor 同步状态。

**Tech Stack:** Swift Process, GDB/MI protocol, WKWebView message handlers

---

## Chunk 1: 调试器核心服务

### Task 1: DebugModels 数据模型

**Files:**
- Create: `DevMac++/Models/DebugModels.swift`

- [ ] **Step 1: 创建调试数据模型**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add debug data models"
```

---

### Task 2: DebuggerService 实现

**Files:**
- Create: `DevMac++/Services/DebuggerService.swift`

- [ ] **Step 1: 创建 DebuggerService.swift**

```swift
import Foundation
import Combine

@MainActor
class DebuggerService: ObservableObject {
    @Published var isDebugging: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentLine: Int? = nil
    @Published var currentFile: String? = nil
    @Published var localVariables: [(name: String, value: String)] = []
    @Published var watchVariables: [WatchVariable] = []
    @Published var callStack: [StackFrame] = []
    @Published var debugOutput: String = ""
    @Published var debuggerError: String? = nil

    private var gdbProcess: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var commandQueue: [String] = []
    private var pendingCommands: [String: (Result<[String: Any], Error>) -> Void] = [:]
    private var sequenceNumber: Int = 0
    private var currentExecutable: String?
    private var buffer: String = ""

    var gdbPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gdb") {
            return "/opt/homebrew/bin/gdb"
        }
        return "gdb"
    }

    // MARK: - Public API

    func startDebug(executable: String, sourceFile: String, breakpoints: Set<Int>) async throws {
        guard !isDebugging else { return }

        currentExecutable = executable
        currentFile = sourceFile
        debuggerError = nil
        debugOutput = ""

        // 启动 GDB in MI 模式
        gdbProcess = Process()
        outputPipe = Pipe()
        inputPipe = Pipe()

        gdbProcess?.executableURL = URL(fileURLWithPath: gdbPath)
        gdbProcess?.arguments = ["-i", "mi", executable]
        gdbProcess?.standardOutput = outputPipe
        gdbProcess?.standardError = outputPipe
        gdbProcess?.standardInput = inputPipe

        // 设置输出读取
        setupOutputHandler()

        do {
            try gdbProcess?.run()
        } catch {
            throw DebugError.launchFailed(error.localizedDescription)
        }

        // 等待 GDB 启动
        try await Task.sleep(nanoseconds: 500_000_000)

        // 启用分段打印长字符串
        sendCommand("-gdb-set print sevenbit-strings off")
        sendCommand("-gdb-set charset UTF-8")

        // 设置文件
        sendCommand("-file-exec-and-symbols \(executable)")

        // 设置所有断点
        for line in breakpoints {
            let result = await sendCommandSync("-break-insert \(sourceFile):\(line)")
            debugOutput += "Breakpoint set at line \(line)\n"
        }

        // 运行到 main
        let runResult = await sendCommandSync("-break-insert main")
        _ = await sendCommandSync("-exec-run")

        isDebugging = true
        isPaused = true
        debugOutput += "Debugging started: \(executable)\n"

        // 获取初始状态
        await refreshState()
    }

    func stopDebug() {
        guard isDebugging else { return }

        Task {
            _ = await sendCommandSync("-exec-abort")
        }

        gdbProcess?.terminate()
        gdbProcess = nil
        outputPipe = nil
        inputPipe = nil

        isDebugging = false
        isPaused = false
        currentLine = nil
        localVariables = []
        callStack = []
        debugOutput += "Debugging stopped.\n"
    }

    func stepInto() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-step")
        await refreshState()
    }

    func stepOver() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-next")
        await refreshState()
    }

    func stepOut() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-finish")
        await refreshState()
    }

    func continue_() async {
        guard isDebugging else { return }
        _ = await sendCommandSync("-exec-continue")
        await refreshState()
    }

    func addWatch(expression: String) {
        guard !watchVariables.contains(where: { $0.name == expression }) else { return }
        watchVariables.append(WatchVariable(name: expression))

        Task {
            if isDebugging {
                let result = await sendCommandSync("-data-evaluate-expression \(expression)")
                if let value = (result["value"] as? String) ?? (result["success"] as? String) {
                    await updateWatchValue(expression: expression, value: value)
                }
            }
        }
    }

    func removeWatch(expression: String) {
        watchVariables.removeAll { $0.name == expression }
    }

    // MARK: - Private

    private func setupOutputHandler() {
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.handleGDBOutput(output)
                }
            }
        }

        gdbProcess?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.handleGDBTerminated()
            }
        }
    }

    private func handleGDBOutput(_ output: String) {
        buffer += output

        // 逐行处理
        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""

        for line in lines.dropLast() {
            parseGDBLine(line)
        }
    }

    private func parseGDBLine(_ line: String) {
        // 跳过空行
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        debugOutput += line + "\n"

        // 异步输出: (gdb) 前缀
        if line.hasPrefix("(gdb)") {
            processPendingAsync()
            return
        }

        // MI 异步消息: ^done, ^running, ^stopped, =...
        if line.hasPrefix("^done") || line.hasPrefix("^running") ||
           line.hasPrefix("^stopped") || line.hasPrefix("=") {
            if let dict = parseMIResult(line) {
                handleAsyncMessage(dict, raw: line)
            }
        }
    }

    private func handleAsyncMessage(_ dict: [String: Any], raw: String: String) {
        if raw.hasPrefix("^stopped") {
            isPaused = true
            if let reason = dict["reason"] as? String {
                debuggerError = nil
                if reason == "exited" {
                    stopDebug()
                    return
                }
                // 解析停止位置
                if let frame = dict["frame"] as? [String: Any] {
                    if let file = frame["file"] as? String {
                        currentFile = file
                    }
                    if let line = frame["line"] as? Int {
                        currentLine = line
                    }
                }
            }
            Task {
                await refreshState()
            }
        }
    }

    private func refreshState() async {
        // 刷新局部变量
        let localsResult = await sendCommandSync("-stack-list-locals 0")
        if let locals = localsResult["locals"] as? [[String: Any]] {
            localVariables = locals.compactMap { local in
                guard let name = local["name"] as? String else { return nil }
                let value = (local["value"] as? String) ?? "..."
                return (name, value)
            }
        }

        // 刷新调用栈
        let stackResult = await sendCommandSync("-stack-list-frames")
        if let stack = stackResult["stack"] as? [[String: Any]] {
            callStack = stack.compactMap { frame in
                guard let level = frame["level"] as? Int,
                      let func_ = frame["func"] as? String else { return nil }
                let file = (frame["file"] as? String) ?? "?"
                let line = (frame["line"] as? Int) ?? 0
                return StackFrame(level: level, function: func_, file: file, line: line)
            }
        }

        // 刷新监视变量
        for i in watchVariables.indices {
            let expr = watchVariables[i].name
            let result = await sendCommandSync("-data-evaluate-expression \(expr)")
            if let value = result["value"] as? String {
                watchVariables[i].value = value
            }
        }
    }

    private func sendCommand(_ cmd: String) {
        guard let inputPipe = inputPipe else { return }
        let data = (cmd + "\n").data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(data)
    }

    private func sendCommandSync(_ cmd: String) async -> [String: Any] {
        let seq = nextSequence()
        let fullCmd = "\(seq)\(cmd)"
        sendCommand(fullCmd)

        return await withCheckedContinuation { continuation in
            pendingCommands[seq] = { result in
                continuation.resume(returning: result)
            }
            // 超时 5 秒
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if let pending = self.pendingCommands.removeValue(forKey: seq) {
                    pending(.success([:]))
                }
            }
        }
    }

    private func nextSequence() -> String {
        sequenceNumber += 1
        return "(\(sequenceNumber)"
    }

    private func parseMIResult(_ line: String) -> [String: Any]? {
        // 简单解析: ^done,var={...} -> 提取 var= 部分
        guard let range = line.range(of: "{") else { return [:] }
        let jsonStr = String(line[range.lowerBound...])
        guard jsonStr.hasSuffix("}") || jsonStr.hasSuffix("\"\n") else { return [:] }

        // 提取 key=value 对
        var result: [String: Any] = [:]
        let pairs = jsonStr.components(separatedBy: ",")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"{ "))
                let value = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\" }"))
                result[key] = value
            }
        }
        return result
    }

    private func processPendingAsync() {
        // 处理等待中的命令回调
    }

    private func handleGDBTerminated() {
        isDebugging = false
        isPaused = false
        debugOutput += "GDB process terminated.\n"
    }
}

enum DebugError: Error, LocalizedError {
    case launchFailed(String)
    case notCompiled
    case gdbNotSigned

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "GDB 启动失败: \(msg)"
        case .notCompiled: return "请先编译程序（带 -g 选项）"
        case .gdbNotSigned: return "GDB 未签名，无法调试进程"
        }
    }
}
```

- [ ] **Step 2: 注册到 DevMacApp.swift**

在 `DevMacApp.swift` 中添加：

```swift
@StateObject private var debuggerService = DebuggerService()
```

传递给 ContentView：

```swift
ContentView()
    .environmentObject(appState)
    .environmentObject(fileService)
    .environmentObject(compilerService)
    .environmentObject(debuggerService)
```

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add DebuggerService with GDB/MI protocol support"
```

---

## Chunk 2: 调试 UI 集成

### Task 3: 菜单和工具栏集成

**Files:**
- Modify: `DevMac++/Views/AppMenuCommands.swift`
- Modify: `DevMac++/Views/ToolbarView.swift`

- [ ] **Step 1: 更新 AppMenuCommands 连接调试服务**

读取并修改 `AppMenuCommands.swift`：

```swift
struct AppMenuCommands: Commands {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileService: FileService
    @EnvironmentObject var compilerService: CompilerService
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some Commands {
        CommandMenu("执行") {
            Button("编译") {
                Task {
                    if let path = appState.currentFilePath {
                        let result = try? await compilerService.compileOnly(filePath: path)
                        appState.compileSuccess = result?.success ?? false
                        appState.compileErrors = result?.errors ?? []
                        appState.selectedBottomTab = .compileLog
                    }
                }
            }
            .keyboardShortcut("\u{F70B}", modifiers: .command) // Cmd+F11

            Button("运行") {
                Task {
                    if let path = appState.currentFilePath {
                        let result = try? await compilerService.compileOnly(filePath: path)
                        if result?.success == true, let exePath = result?.executablePath {
                            await runExecutable(path: exePath)
                        }
                    }
                }
            }
            .keyboardShortcut("\u{F70A}", modifiers: .command) // Cmd+F10

            Button("编译运行") {
                Task {
                    await compileAndRun()
                }
            }
            .keyboardShortcut("\u{F709}", modifiers: .command) // Cmd+F9

            Divider()

            Button("调试") {
                Task {
                    await startDebug()
                }
            }
            .keyboardShortcut("\u{F708}", modifiers: .command) // Cmd+F8

            Button("停止调试") {
                debuggerService.stopDebug()
                appState.isDebugging = false
            }
            .keyboardShortcut("\u{F702}", modifiers: .command) // Cmd+F2
        }
    }

    @MainActor
    func compileAndRun() async {
        guard let path = appState.currentFilePath else { return }

        do {
            let result = try await compilerService.compileOnly(filePath: path)
            appState.compileLog = result.output
            appState.compileSuccess = result.success
            appState.compileErrors = result.errors
            appState.selectedBottomTab = .compileLog

            if result.success, let exePath = result.executablePath {
                await runExecutable(path: exePath)
            }
        } catch {
            appState.compileOutput = "Error: \(error.localizedDescription)"
        }
    }

    @MainActor
    func startDebug() async {
        guard let path = appState.currentFilePath else { return }

        do {
            // 编译带 -g 的版本
            let result = try await compilerService.compileForDebug(filePath: path)
            appState.compileLog = result.output
            appState.selectedBottomTab = .compileLog

            if result.success, let exePath = result.executablePath {
                try debuggerService.startDebug(
                    executable: exePath,
                    sourceFile: path,
                    breakpoints: appState.breakpoints
                )
                appState.isDebugging = true
                appState.selectedSidebarTab = .debug
                appState.selectedBottomTab = .debug
            }
        } catch {
            appState.compileOutput = "Debug error: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileResult
        }
    }

    @MainActor
    func runExecutable(path: String) async {
        let script = """
        tell application "Terminal"
            do script "cd \"$(dirname '\(path)')\" && '\\(path)'; echo ''; read -n 1 -s -r -p '按任意键继续...'"
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
```

- [ ] **Step 2: 更新 ToolbarView 连接调试操作**

读取 `ToolbarView.swift`，修改调试按钮连接 debuggerService：

```swift
// 编译行内添加:
ToolbarButton(icon: "hammer", tooltip: "编译 (Cmd+F11)") {
    // 编译
}
ToolbarButton(icon: "play", tooltip: "运行 (Cmd+F10)", tint: Color(hex: "#4caf50")) {
    // 运行
}
ToolbarButton(icon: "play.fill", tooltip: "编译运行 (Cmd+F9)", tint: Color(hex: "#ff9800")) {
    // 编译运行
}

// 调试行内添加 (需要 @EnvironmentObject):
ToolbarButton(icon: "ant", tooltip: "调试 (Cmd+F8)", tint: Color(hex: "#2196f3")) {
    Task { await startDebug() }
}
ToolbarButton(icon: "pause", tooltip: "暂停") {
    // 暂停
}
ToolbarButton(icon: "stop", tooltip: "停止 (Cmd+F2)") {
    debuggerService.stopDebug()
}
ToolbarButton(icon: "arrow.down.to.line", tooltip: "单步进入 (Cmd+F11)") {
    Task { await debuggerService.stepInto() }
}
ToolbarButton(icon: "arrow.right.to.line", tooltip: "单步跳过 (Cmd+F10)") {
    Task { await debuggerService.stepOver() }
}
ToolbarButton(icon: "arrow.up.to.line", tooltip: "单步跳出 (Cmd+Shift+F11)") {
    Task { await debuggerService.stepOut() }
}
```

ToolbarView 需要添加 `@EnvironmentObject var debuggerService: DebuggerService`。

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: integrate debugger with menu and toolbar"
```

---

### Task 4: 调试状态同步到 Monaco Editor

**Files:**
- Modify: `DevMac++/Views/MonacoEditorView.swift`
- Modify: `DevMac++/Views/DebugSidebarView.swift` (创建独立文件)

- [ ] **Step 1: 添加 goToLine 方法到 MonacoEditorView Coordinator**

在 `MonacoEditorView.swift` 的 Coordinator 类中添加：

```swift
func goToLine(_ line: Int) {
    guard let webView = self.webView else { return }
    let js = "window.editor.revealLineInCenter(\(line)); window.editor.setPosition({ lineNumber: \(line), column: 1 });"
    webView.evaluateJavaScript(js, completionHandler: nil)
}

func highlightDebugLine(_ line: Int?) {
    guard let webView = self.webView else { return }

    if let currentLine = currentDebugLine {
        // 移除旧的高亮
        let removeJs = """
        if (window.debugLineDecoration) {
            window.editor.deltaDecorations([window.debugLineDecoration], []);
            window.debugLineDecoration = null;
        }
        """
        webView.evaluateJavaScript(removeJs, completionHandler: nil)
    }

    currentDebugLine = line

    if let line = line {
        let js = """
        if (window.editor) {
            window.debugLineDecoration = window.editor.deltaDecorations([], [{
                range: new monaco.Range(\(line), 1, \(line), 1),
                options: {
                    isWholeLine: true,
                    className: 'debug-line',
                    glyphMarginClassName: 'debug-glyph'
                }
            }]);
        }
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

private var currentDebugLine: Int?
```

- [ ] **Step 2: 添加调试行高亮样式到 editor.html**

在 `DevMac++/Resources/monaco/editor.html` 的 `<style>` 中添加：

```css
.debug-line {
    background: rgba(0, 120, 212, 0.3) !important;
}
.debug-glyph {
    background: #0078d4;
    border-radius: 50%;
    width: 10px !important;
    height: 10px !important;
    margin-left: 3px;
    margin-top: 5px;
}
```

- [ ] **Step 3: 在 MonacoEditorView 的 updateNSView 中同步调试状态**

修改 `updateNSView` 方法：

```swift
func updateNSView(_ webView: WKWebView, context: Context) {
    // 同步调试当前行
    if let line = appState.currentDebugLine {
        context.coordinator.highlightDebugLine(line)
    }
}
```

- [ ] **Step 4: 添加 currentDebugLine 到 AppState**

在 `AppState.swift` 中已有 `@Published var currentDebugLine: Int?`，确认存在。如不存在则添加。

- [ ] **Step 5: 同步 debuggerService 状态到 appState**

在 `DebuggerService.startDebug` 成功后，添加状态同步：

```swift
// 在 startDebug 成功后添加
appState.currentDebugLine = currentLine
```

同时在 `refreshState()` 中：

```swift
// 在 refreshState 完成后
appState.currentDebugLine = currentLine
```

- [ ] **Step 6: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: sync debug state with Monaco Editor - highlight current line"
```

---

## Chunk 3: 监视变量 UI

### Task 5: 监视面板增强

**Files:**
- Modify: `DevMac++/Views/SidebarView.swift` (WatchView)

- [ ] **Step 1: 增强 WatchView 添加输入框**

在 `SidebarView.swift` 中修改 `WatchView`：

```swift
struct WatchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService
    @State private var newWatchExpression: String = ""
    @State private var isAddingWatch: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
```

- [ ] **Step 2: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add watch panel with add/remove functionality"
```

---

## 完成标准

Plan 4 完成后，应用应该：

- [ ] Cmd+F8 启动 GDB 调试（编译带 -g，自动启动调试器）
- [ ] 调试面板显示在左侧边栏（监视/局部/栈）
- [ ] 点击 Monaco Editor 行号边距设置/删除断点（红色圆点）
- [ ] 当前调试行高亮（蓝色）
- [ ] 监视面板可添加/删除监视表达式
- [ ] 局部变量窗口显示当前作用域变量
- [ ] 调用栈窗口显示函数调用链
- [ ] Cmd+F10 单步跳过，Cmd+F11 单步进入
- [ ] Cmd+Shift+F11 单步跳出
- [ ] Cmd+F9 继续运行到下一个断点
- [ ] Cmd+F2 停止调试
- [ ] 调试输出显示在底部"调试"标签页
- [ ] 编译成功，推送到 GitHub

**下一步：** Plan 5 - 辅助功能（模板、查找替换、帮助文档）
