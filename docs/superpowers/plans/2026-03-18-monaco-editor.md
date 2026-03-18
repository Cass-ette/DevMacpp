# Monaco Editor 集成实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Monaco Editor 集成到 DevMac++，替换占位符编辑器，支持 C++ 语法高亮、文件操作和断点标记

**Architecture:** Monaco Editor 通过 WKWebView 嵌入 SwiftUI，Swift 与 JavaScript 通过 WKScriptMessageHandler 双向通信。编辑器配置为纯文本模式（禁用所有智能功能）

**Tech Stack:** Swift 5.9+, SwiftUI, WKWebView, Monaco Editor (bundled locally)

---

## Chunk 1: Monaco Editor 基础集成

### Task 1: 下载并配置 Monaco Editor

**Files:**
- Create: `DevMac++/Resources/monaco/` (Monaco Editor 文件)
- Create: `DevMac++/Views/MonacoEditorView.swift`

- [ ] **Step 1: 下载 Monaco Editor**

Monaco Editor 从 npm 包构建，需要包含核心文件。在项目目录执行：

```bash
cd /Users/chenzilve/Projects/devmac++/DevMac++/Resources/monaco

# 下载 Monaco Editor（从 CDN 缓存版本，稳定版本）
curl -L "https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/min/vs" -o vs.zip --max-time 60
unzip -q vs.zip
rm vs.zip
```

注意：如果下载失败，手动从 https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/min/vs/ 下载所需文件。

- [ ] **Step 2: 创建 Monaco HTML 加载器**

创建 `DevMac++/Resources/monaco/editor.html`：

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: #1e1e1e;
        }
        #container {
            width: 100%;
            height: 100%;
        }
    </style>
</head>
<body>
    <div id="container"></div>
    <script src="vs/loader.js"></script>
    <script>
        require.config({ paths: { vs: 'vs' } });
        require(['vs/editor/editor.main'], function () {
            // 创建编辑器
            window.editor = monaco.editor.create(document.getElementById('container'), {
                value: '',
                language: 'cpp',
                theme: 'vs-dark',
                fontSize: 13,
                fontFamily: 'Monaco, Menlo, monospace',
                lineNumbers: 'on',
                glyphMargin: true,
                folding: false,
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                automaticLayout: true,
                wordWrap: 'off',
                tabSize: 4,
                insertSpaces: true,
                renderWhitespace: 'selection',
                contextmenu: true,
                
                // 禁用所有智能功能（纯文本模式）
                quickSuggestions: false,
                suggestOnTriggerCharacters: false,
                acceptSuggestionOnEnter: 'off',
                tabCompletion: 'off',
                wordBasedSuggestions: 'off',
                parameterHints: { enabled: false },
                hover: { enabled: false },
                formatOnType: false,
                formatOnPaste: false,
                autoIndent: 'none',
                detectIndentation: false,
                renderLineHighlight: 'line',
                scrollbar: {
                    vertical: 'auto',
                    horizontal: 'auto',
                    useShadows: false,
                    verticalScrollbarSize: 10,
                    horizontalScrollbarSize: 10
                }
            });

            // 监听内容变化
            window.editor.onDidChangeModelContent(() => {
                const content = window.editor.getValue();
                window.webkit.messageHandlers.contentChange.postMessage({
                    content: content,
                    cursorLine: window.editor.getPosition().lineNumber,
                    cursorColumn: window.editor.getPosition().column
                });
            });

            // 监听光标位置变化
            window.editor.onDidChangeCursorPosition((e) => {
                window.webkit.messageHandlers.cursorChange.postMessage({
                    line: e.position.lineNumber,
                    column: e.position.column
                });
            });

            // 监听点击断点区域（行号左边距）
            window.editor.onMouseDown((e) => {
                if (e.target.type === 2) { // glyphMargin
                    const lineNumber = e.target.position?.lineNumber;
                    if (lineNumber) {
                        window.webkit.messageHandlers.breakpointToggle.postMessage({
                            line: lineNumber
                        });
                    }
                }
            });

            // 通知 Swift 编辑器已初始化
            window.webkit.messageHandlers.editorReady.postMessage({});
        });
    </script>
</body>
</html>
```

- [ ] **Step 2: 创建 MonacoEditorView.swift**

创建 `DevMac++/Views/MonacoEditorView.swift`：

```swift
import SwiftUI
import WebKit

struct MonacoEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 添加消息处理器
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "editorReady")
        contentController.add(context.coordinator, name: "contentChange")
        contentController.add(context.coordinator, name: "cursorChange")
        contentController.add(context.coordinator, name: "breakpointToggle")
        config.userContentController = contentController
        
        // 配置
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        
        // 加载本地 HTML
        if let htmlPath = Bundle.main.path(forResource: "editor", ofType: "html", inDirectory: "monaco") {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // 同步内容（如果需要）
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let appState: AppState
        weak var webView: WKWebView?
        
        init(appState: AppState) {
            self.appState = appState
            super.init()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                switch message.name {
                case "editorReady":
                    self.appState.editorReady = true
                    self.syncBreakpoints()
                    
                case "contentChange":
                    if let content = body["content"] as? String {
                        self.appState.fileContent = content
                        self.appState.isModified = true
                        self.appState.fileSize = content.utf8.count
                    }
                    if let line = body["cursorLine"] as? Int {
                        self.appState.cursorPosition.line = line
                    }
                    if let column = body["cursorColumn"] as? Int {
                        self.appState.cursorPosition.column = column
                    }
                    
                case "cursorChange":
                    if let line = body["line"] as? Int {
                        self.appState.cursorPosition.line = line
                    }
                    if let column = body["column"] as? Int {
                        self.appState.cursorPosition.column = column
                    }
                    
                case "breakpointToggle":
                    if let line = body["line"] as? Int {
                        self.toggleBreakpoint(line: line)
                    }
                    
                default:
                    break
                }
            }
        }
        
        func setWebView(_ webView: WKWebView) {
            self.webView = webView
        }
        
        private func toggleBreakpoint(line: Int) {
            if self.appState.breakpoints.contains(line) {
                self.appState.breakpoints.remove(line)
            } else {
                self.appState.breakpoints.insert(line)
            }
            self.syncBreakpoints()
        }
        
        func syncBreakpoints() {
            guard let webView = self.webView else { return }
            
            let js = """
            if (window.editor) {
                window.editor.deltaDecorations(
                    [],
                    \(self.appState.breakpoints.map { "{\n                        range: new monaco.Range(\($0), 1, \($0), 1),\n                        options: {\n                            isWholeLine: true,\n                            className: 'breakpoint-line',\n                            glyphMarginClassName: 'breakpoint-glyph'\n                        }\n                    }" }.joined(separator: ",\n                    ")
                );
            }
            """
            
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func setContent(_ content: String) {
            guard let webView = self.webView else { return }
            let escaped = content.replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            webView.evaluateJavaScript("window.editor.setValue('\(escaped)')", completionHandler: nil)
        }
    }
}
```

- [ ] **Step 3: 更新 AppState 添加 editorReady**

在 `AppState.swift` 中添加：

```swift
@Published var editorReady: Bool = false
```

- [ ] **Step 4: 更新 project.yml 添加 Resources**

```yaml
targets:
  DevMac++:
    resources:
      - path: DevMac++/Resources
        excludes:
          - "**/.gitkeep"
```

- [ ] **Step 5: 构建验证**

Cmd+B，确认无错误。可能会有关于 `editorReady` 的编译错误，先忽略，等 Task 2 更新 ContentView。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Monaco Editor integration with pure text mode"
```

---

### Task 2: 替换 EditorPlaceholderView

**Files:**
- Modify: `DevMac++/Views/ContentView.swift`

- [ ] **Step 1: 更新 ContentView**

读取当前的 `ContentView.swift`，将 `EditorPlaceholderView()` 替换为 `MonacoEditorView()`：

```swift
// 删除 EditorPlaceholderView

// 在 ContentView 中添加
MonacoEditorView()
    .environmentObject(appState)
```

- [ ] **Step 2: 更新 coordinator 引用**

修改 `MonacoEditorView.swift`，在 `makeNSView` 返回 webView 后设置 coordinator 的引用：

```swift
let webView = WKWebView(frame: .zero, configuration: config)
webView.setValue(false, forKey: "drawsBackground")
context.coordinator.setWebView(webView)
```

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: replace editor placeholder with Monaco Editor"
```

---

## Chunk 2: 文件操作

### Task 3: 文件操作功能

**Files:**
- Create: `DevMac++/Services/FileService.swift`

- [ ] **Step 1: 创建 FileService.swift**

```swift
import Foundation
import SwiftUI

class FileService: ObservableObject {
    @Published var currentFilePath: String?
    
    func newFile(appState: AppState) {
        appState.currentFilePath = nil
        appState.currentFileName = "未保存.cpp"
        appState.fileContent = ""
        appState.isModified = false
        appState.fileSize = 0
    }
    
    func openFile(appState: AppState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.cppSource, .cSource, .header]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                currentFilePath = url.path
                appState.currentFilePath = url.path
                appState.currentFileName = url.lastPathComponent
                appState.fileContent = content
                appState.isModified = false
                appState.fileSize = content.utf8.count
            } catch {
                print("Failed to open file: \(error)")
            }
        }
    }
    
    func saveFile(appState: AppState, editor: MonacoEditorView.Coordinator?) {
        if let path = currentFilePath {
            saveToPath(path, appState: appState)
        } else {
            saveAs(appState: appState, editor: editor)
        }
    }
    
    func saveAs(appState: AppState, editor: MonacoEditorView.Coordinator?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.cppSource]
        panel.nameFieldStringValue = appState.currentFileName
        
        if panel.runModal() == .OK, let url = panel.url {
            saveToPath(url.path, appState: appState)
            currentFilePath = url.path
        }
    }
    
    private func saveToPath(_ path: String, appState: AppState) {
        do {
            try appState.fileContent.write(toFile: path, atomically: true, encoding: .utf8)
            appState.isModified = false
            let name = (path as NSString).lastPathComponent
            appState.currentFileName = name
            appState.currentFilePath = path
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}
```

- [ ] **Step 2: 更新 AppState 添加 editorReady 和 fileService**

在 `AppState.swift` 中添加：

```swift
@Published var editorReady: Bool = false
```

创建 `FileService` 实例并通过 Environment 传递。

- [ ] **Step 3: 更新 AppMenuCommands 连接文件操作**

在 `AppMenuCommands.swift` 中，更新文件菜单的按钮操作：

```swift
CommandMenu("文件") {
    Button("新建") {
        fileService.newFile(appState: appState)
    }
    .keyboardShortcut("n", modifiers: .command)
    
    Button("打开...") {
        fileService.openFile(appState: appState)
    }
    .keyboardShortcut("o", modifiers: .command)
    
    Divider()
    
    Button("保存") {
        // 获取 editor coordinator 并保存
    }
    .keyboardShortcut("s", modifiers: .command)
    
    Button("另存为...") {
        // 保存为
    }
    .keyboardShortcut("s", modifiers: [.command, .shift])
    
    Divider()
    
    Button("关闭") {
        // 关闭文件
    }
    .keyboardShortcut("w", modifiers: .command)
}
```

- [ ] **Step 4: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add file operations - new, open, save"
```

---

## Chunk 3: 断点调试集成

### Task 4: 断点标记与同步

**Files:**
- Modify: `DevMac++/Views/MonacoEditorView.swift`
- Modify: `DevMac++/Resources/monaco/editor.html`

- [ ] **Step 1: 添加断点 CSS 样式**

在 `editor.html` 的 `<style>` 中添加：

```css
.breakpoint-line {
    background: rgba(255, 0, 0, 0.2) !important;
}
.breakpoint-glyph {
    background: #f00;
    border-radius: 50%;
    width: 10px !important;
    height: 10px !important;
    margin-left: 3px;
    margin-top: 5px;
}
```

- [ ] **Step 2: 实现断点同步**

确保 `MonacoEditorView.swift` 中的 `syncBreakpoints()` 方法正确工作。

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add breakpoint marking and sync with Monaco Editor"
```

---

## 完成标准

Plan 2 完成后，应用应该：

- [ ] Monaco Editor 正常加载，显示 C++ 代码
- [ ] C++ 语法高亮正常
- [ ] 行号显示正常
- [ ] 点击行号边距可以切换断点
- [ ] 断点显示为红色圆点
- [ ] 新建/打开/保存文件功能正常
- [ ] 编辑器内容与 appState 同步
- [ ] 光标位置同步到状态栏
- [ ] 文件修改状态正确显示（标签圆点）
- [ ] 纯文本模式（无智能补全、无错误提示）
- [ ] 编译成功，推送到 GitHub

**下一步：** Plan 3 - 编译器服务（GCC 集成）
