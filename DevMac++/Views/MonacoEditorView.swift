import SwiftUI
import WebKit
import Combine

struct MonacoEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 添加消息处理器
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "editorReady")
        contentController.add(context.coordinator, name: "contentChange")
        contentController.add(context.coordinator, name: "cursorChange")
        contentController.add(context.coordinator, name: "breakpointSync")
        config.userContentController = contentController

        // 配置
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        // 保存 webView 引用到 coordinator 和 appState（用于打印等）
        context.coordinator.webView = webView
        appState.currentWebView = webView

        // 加载本地 HTML
        if let htmlPath = Bundle.main.path(forResource: "editor", ofType: "html", inDirectory: "monaco-editor") {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 显式引用 debuggerService.currentLine，让 SwiftUI 追踪依赖
        let line = debuggerService.currentLine
        context.coordinator.setDebugLine(line)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, debuggerService: debuggerService)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let appState: AppState
        let debuggerService: DebuggerService
        weak var webView: WKWebView?
        private var cancellables = Set<AnyCancellable>()
        /// 记录上一次 JS 设定的内容，避免循环更新
        private var lastJSContent: String = ""

        init(appState: AppState, debuggerService: DebuggerService) {
            self.appState = appState
            self.debuggerService = debuggerService
            super.init()

            // 监听 currentLine 变化，直接更新 JS 调试行
            debuggerService.$currentLine
                .receive(on: DispatchQueue.main)
                .sink { [weak self] line in
                    self?.setDebugLine(line)
                }
                .store(in: &cancellables)

            // 监听 fileContent 变化（Swift 端打开文件时），更新 Monaco
            appState.$fileContent
                .dropFirst()  // 忽略初始化时的值（由 editorReady 处理）
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newContent in
                    guard let self = self else { return }
                    // lastJSContent 记录 Monaco 当前实际内容，避免无意义重复调用
                    if newContent != self.lastJSContent {
                        self.lastJSContent = newContent
                        self.setContent(newContent)
                    }
                }
                .store(in: &cancellables)

            // 监听 showFindWidget 变化（打开查找 widget）
            appState.$showFindWidget
                .filter { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self, let webView = self.webView else { return }
                    webView.evaluateJavaScript("if (window.openFindWidget) window.openFindWidget();", completionHandler: nil)
                }
                .store(in: &cancellables)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }

            DispatchQueue.main.async {
                switch message.name {
                case "editorReady":
                    self.appState.editorReady = true
                    // 将当前内容同步到 Monaco（打开文件后编辑器刚加载时）
                    self.lastJSContent = self.appState.fileContent
                    self.setContent(self.appState.fileContent)
                    self.syncBreakpoints()

                case "contentChange":
                    if let content = body["content"] as? String {
                        self.lastJSContent = content
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

                case "breakpointSync":
                    if let lines = body["lines"] as? [Int] {
                        self.syncBreakpointsFromJS(lines: Set(lines))
                    }

                default:
                    break
                }
            }
        }

        /// JS 通知完整断点列表 → 更新 Swift 状态
        private func syncBreakpointsFromJS(lines: Set<Int>) {
            let oldSet = self.appState.breakpoints
            self.appState.breakpoints = lines

            if self.debuggerService.isDebugging {
                let added = lines.subtracting(oldSet)
                let removed = oldSet.subtracting(lines)

                for line in added {
                    self.debuggerService.queueBreakpointChange(line: line, add: true)
                }
                for line in removed {
                    self.debuggerService.queueBreakpointChange(line: line, add: false)
                }

                // 如果程序已暂停，立即应用（不用等下次 stop）
                if self.debuggerService.isPaused {
                    Task { @MainActor in
                        await self.debuggerService.applyPendingBreakpointChangesNow()
                    }
                }
            }
        }

        /// 恢复断点装饰（editorReady 时从 appState 恢复）
        func syncBreakpoints() {
            guard let webView = self.webView, self.appState.editorReady else { return }
            let lines = self.appState.breakpoints.sorted()
            let linesJson = "[\(lines.map { String($0) }.joined(separator: ","))]"
            let js = "window.setBreakpoints(\(linesJson), null);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        /// 设置调试行（不影响断点）
        func setDebugLine(_ line: Int?) {
            guard let webView = self.webView, self.appState.editorReady else { return }
            let js: String
            if let line = line {
                js = "window.setDebugLine(\(line));"
            } else {
                js = "window.setDebugLine(null);"
            }
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func setContent(_ content: String) {
            guard let webView = self.webView else { return }
            // fragmentsAllowed 允许裸字符串序列化为 JSON 字符串字面量，安全传递任意内容
            if let jsonData = try? JSONSerialization.data(withJSONObject: content, options: .fragmentsAllowed),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                webView.evaluateJavaScript("if (window.setContent) window.setContent(\(jsonStr));", completionHandler: nil)
            }
        }

        func goToLine(_ line: Int) {
            guard let webView = self.webView else { return }
            let js = "window.editor.revealLineInCenter(\(line)); window.editor.setPosition({ lineNumber: \(line), column: 1 });"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func goToLine(_ line: Int, column: Int) {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("if (window.editor) window.editor.setPosition({ lineNumber: \(line), column: \(column) });", completionHandler: nil)
            webView.evaluateJavaScript("if (window.editor) window.editor.revealLineInCenter(\(line));", completionHandler: nil)
        }
    }
}
