import SwiftUI
import WebKit

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
        contentController.add(context.coordinator, name: "breakpointToggle")
        config.userContentController = contentController

        // 配置
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        // 保存 webView 引用到 coordinator
        context.coordinator.webView = webView

        // 加载本地 HTML
        if let htmlPath = Bundle.main.path(forResource: "editor", ofType: "html", inDirectory: "monaco-editor") {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 同步调试状态
        if let line = context.coordinator.debuggerService.currentLine {
            context.coordinator.highlightDebugLine(line)
        } else {
            context.coordinator.highlightDebugLine(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, debuggerService: debuggerService)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let appState: AppState
        let debuggerService: DebuggerService
        weak var webView: WKWebView?
        var currentDebugLine: Int? = nil

        init(appState: AppState, debuggerService: DebuggerService) {
            self.appState = appState
            self.debuggerService = debuggerService
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

        private func toggleBreakpoint(line: Int) {
            if self.appState.breakpoints.contains(line) {
                self.appState.breakpoints.remove(line)
            } else {
                self.appState.breakpoints.insert(line)
            }
            self.syncBreakpoints()
        }

        func syncBreakpoints() {
            guard let webView = self.webView, self.appState.editorReady else { return }

            // 构建断点装饰器数组
            let decorations = self.appState.breakpoints.map { lineNum -> String in
                return """
                {
                    range: new monaco.Range(\(lineNum), 1, \(lineNum), 1),
                    options: {
                        isWholeLine: true,
                        className: 'breakpoint-line',
                        glyphMarginClassName: 'breakpoint-glyph'
                    }
                }
                """
            }.joined(separator: ",\n")

            let js = """
            if (window.editor) {
                window.editor.deltaDecorations([], [\(decorations)]);
            }
            """

            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func setContent(_ content: String) {
            guard let webView = self.webView else { return }
            // 转义特殊字符
            let escaped = content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView.evaluateJavaScript("if (window.editor) window.editor.setValue('\(escaped)');", completionHandler: nil)
        }

        func highlightDebugLine(_ line: Int?) {
            guard let webView = self.webView else { return }

            let removeJs = """
            if (window.debugLineDecoration) {
                window.editor.deltaDecorations([window.debugLineDecoration], []);
                window.debugLineDecoration = null;
            }
            """
            webView.evaluateJavaScript(removeJs, completionHandler: nil)

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
                    window.editor.revealLineInCenter(\(line));
                }
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
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
