import SwiftUI
import AppKit

struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var compilerService: CompilerService
    @EnvironmentObject var debuggerService: DebuggerService

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
                ToolbarButton(icon: "hammer", tooltip: "编译 (Cmd+F11)") {
                    Task { @MainActor in
                        if let path = appState.currentFilePath {
                            let result = try? await compilerService.compileOnly(filePath: path)
                            appState.compileSuccess = result?.success ?? false
                            appState.compileErrors = result?.errors ?? []
                            appState.selectedBottomTab = .compileLog
                        }
                    }
                }
                ToolbarButton(icon: "play", tooltip: "运行 (Cmd+F10)", tint: Color(hex: "#4caf50")) {
                    Task { @MainActor in
                        if let path = appState.currentFilePath {
                            let result = try? await compilerService.compileOnly(filePath: path)
                            if result?.success == true, let exePath = result?.executablePath {
                                await runExecutable(path: exePath)
                            }
                        }
                    }
                }
                ToolbarButton(icon: "play.fill", tooltip: "编译运行 (Cmd+F9)", tint: Color(hex: "#ff9800")) {
                    Task { await compileAndRun() }
                }
                ToolbarButton(icon: "arrow.clockwise", tooltip: "重新编译") {}
                ToolbarButton(icon: "trash", tooltip: "清理") {}

                ToolbarDivider()

                ToolbarButton(icon: "ant", tooltip: "调试 (Cmd+F8)", tint: Color(hex: "#2196f3")) {
                    Task { await startDebug() }
                }
                ToolbarButton(icon: "pause", tooltip: "继续运行") {
                    Task { await debuggerService.continue_() }
                }
                ToolbarButton(icon: "stop", tooltip: "停止 (Cmd+F2)") {
                    debuggerService.stopDebug()
                    appState.isDebugging = false
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

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    @MainActor
    private func compileAndRun() async {
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
    private func startDebug() async {
        guard let path = appState.currentFilePath else { return }

        do {
            let result = try await compilerService.compileForDebug(filePath: path)
            appState.compileLog = result.output
            appState.selectedBottomTab = .compileLog

            if result.success, let exePath = result.executablePath {
                try await debuggerService.startDebug(
                    executable: exePath,
                    sourceFile: path,
                    breakpoints: appState.breakpoints
                )
                appState.isDebugging = true
                appState.selectedBottomTab = .debug
            }
        } catch {
            appState.compileOutput = "Debug error: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileResult
        }
    }

    @MainActor
    private func runExecutable(path: String) async {
        let script = """
        tell application "Terminal"
            do script "cd \"$(dirname '\(path)')\" && '\(path)'; echo ''; read -n 1 -s -r -p '按任意键继续...'"
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
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
