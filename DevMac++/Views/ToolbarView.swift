import SwiftUI
import AppKit
import WebKit

struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var compilerService: CompilerService
    @EnvironmentObject var debuggerService: DebuggerService
    @EnvironmentObject var fileService: FileService
    @EnvironmentObject var templateService: TemplateService
    @EnvironmentObject var runtimeService: RuntimeService

    var body: some View {
        VStack(spacing: 0) {
            // 第一行：文件操作 + 编辑操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "doc", tooltip: "新建 (Cmd+N)") {
                    appState.showTemplatePicker = true
                }
                ToolbarButton(icon: "folder", tooltip: "打开 (Cmd+O)") {
                    fileService.openFile(appState: appState)
                }
                ToolbarButton(icon: "square.and.arrow.down", tooltip: "保存 (Cmd+S)") {
                    fileService.saveFile(appState: appState)
                }
                ToolbarButton(icon: "square.and.arrow.down.on.square", tooltip: "另存为") {
                    fileService.saveAs(appState: appState)
                }
                ToolbarButton(icon: "xmark", tooltip: "关闭 (Cmd+W)") {
                    fileService.newFile(appState: appState)
                }

                ToolbarDivider()

                ToolbarButton(icon: "printer", tooltip: "打印") {
                    if let webView = appState.currentWebView {
                        let printInfo = NSPrintInfo.shared
                        printInfo.horizontalPagination = .fit
                        printInfo.verticalPagination = .automatic
                        let printOp = NSPrintOperation(view: webView, printInfo: printInfo)
                        printOp.run()
                    }
                }

                ToolbarDivider()

                ToolbarButton(icon: "scissors", tooltip: "剪切 (Cmd+X)") {
                    NSApp.sendAction(Selector(("cut:")), to: nil, from: nil)
                }
                ToolbarButton(icon: "doc.on.doc", tooltip: "复制 (Cmd+C)") {
                    NSApp.sendAction(Selector(("copy:")), to: nil, from: nil)
                }
                ToolbarButton(icon: "doc.on.clipboard", tooltip: "粘贴 (Cmd+V)") {
                    NSApp.sendAction(Selector(("paste:")), to: nil, from: nil)
                }

                ToolbarDivider()

                ToolbarButton(icon: "arrow.uturn.backward", tooltip: "撤销 (Cmd+Z)") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                ToolbarButton(icon: "arrow.uturn.forward", tooltip: "重做 (Cmd+Shift+Z)") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }

                ToolbarDivider()

                ToolbarButton(icon: "magnifyingglass", tooltip: "查找 (Cmd+F)") {
                    appState.showFindWidget = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.showFindWidget = false
                    }
                }
                ToolbarButton(icon: "arrow.left.arrow.right", tooltip: "替换 (Cmd+H)") {
                    appState.showFindWidget = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.showFindWidget = false
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 第二行：编译 + 调试操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "hammer", tooltip: "编译") {
                    Task { @MainActor in
                        if appState.currentFilePath == nil {
                            fileService.saveFile(appState: appState)
                            if appState.currentFilePath == nil { return }
                        }
                        if let path = appState.currentFilePath {
                            appState.compileLog = "正在编译...\n"
                            appState.selectedBottomTab = .compileLog
                            let result = try? await compilerService.compileOnly(filePath: path)
                            appState.compileSuccess = result?.success ?? false
                            appState.compileErrors = result?.errors ?? []
                            appState.compileLog = result?.output ?? ""
                        }
                    }
                }
                ToolbarButton(icon: "play", tooltip: "运行", tint: Color(hex: "#4caf50")) {
                    Task { @MainActor in
                        if appState.currentFilePath == nil {
                            fileService.saveFile(appState: appState)
                            if appState.currentFilePath == nil { return }
                        }
                        if let path = appState.currentFilePath {
                            appState.compileLog = "正在编译...\n"
                            appState.selectedBottomTab = .compileLog
                            let result = try? await compilerService.compileOnly(filePath: path)
                            if result?.success == true, let exePath = result?.executablePath {
                                appState.selectedBottomTab = .runtime
                                let workingDir = (path as NSString).deletingLastPathComponent
                                runtimeService.run(executable: exePath, workingDir: workingDir)
                            } else {
                                appState.compileSuccess = false
                                appState.compileErrors = result?.errors ?? []
                                appState.compileLog = result?.output ?? ""
                            }
                        }
                    }
                }
                ToolbarButton(icon: "play.fill", tooltip: "编译运行 (Cmd+F9)", tint: Color(hex: "#ff9800")) {
                    Task { await compileAndRun() }
                }
                ToolbarButton(icon: "arrow.clockwise", tooltip: "重新编译") {
                    Task { @MainActor in
                        fileService.saveFile(appState: appState)
                        if let path = appState.currentFilePath {
                            appState.compileLog = "正在编译...\n"
                            appState.selectedBottomTab = .compileLog
                            let result = try? await compilerService.compileOnly(filePath: path)
                            appState.compileSuccess = result?.success ?? false
                            appState.compileErrors = result?.errors ?? []
                            appState.compileLog = result?.output ?? ""
                        }
                    }
                }
                ToolbarButton(icon: "trash", tooltip: "清理") {
                    if let path = appState.currentFilePath {
                        let msg = compilerService.clean(filePath: path)
                        appState.compileLog = msg
                        appState.selectedBottomTab = .compileLog
                    }
                }

                ToolbarDivider()

                ToolbarButton(icon: "ant", tooltip: "调试 (Cmd+F8)", tint: Color(hex: "#2196f3")) {
                    Task { await startDebug() }
                }
                ToolbarButton(icon: "pause", tooltip: "继续运行 (Cmd+F3)") {
                    Task { await debuggerService.continue_() }
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

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $appState.showTemplatePicker) {
            TemplatePickerView()
        }
    }

    @MainActor
    private func compileAndRun() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }

        guard let path = appState.currentFilePath else { return }

        do {
            appState.compileLog = "正在编译...\n"
            appState.selectedBottomTab = .compileLog
            let result = try await compilerService.compileOnly(filePath: path)
            appState.compileLog = result.output
            appState.compileSuccess = result.success
            appState.compileErrors = result.errors

            if result.success, let exePath = result.executablePath {
                appState.selectedBottomTab = .runtime
                let workingDir = (path as NSString).deletingLastPathComponent
                runtimeService.run(executable: exePath, workingDir: workingDir)
            }
        } catch {
            appState.compileLog = "Error: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileLog
        }
    }

    @MainActor
    private func startDebug() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }

        guard let path = appState.currentFilePath else { return }

        do {
            appState.compileLog = "正在编译（调试模式）...\n"
            appState.selectedBottomTab = .compileLog
            let result = try await compilerService.compileForDebug(filePath: path)
            appState.compileLog = result.output
            appState.compileSuccess = result.success
            appState.compileErrors = result.errors

            if result.success, let exePath = result.executablePath {
                try await debuggerService.startDebug(
                    executable: exePath,
                    sourceFile: path,
                    breakpoints: appState.breakpoints
                )
                appState.selectedBottomTab = .debug
            }
        } catch {
            appState.compileLog = "调试错误: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileLog
        }
    }

}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var tint: Color = Color(hex: "#cccccc")
    let action: () -> Void

    @State private var isHovered = false
    @State private var showTooltip = false

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
        .overlay(alignment: .bottom) {
            if showTooltip {
                tooltipView
                    .offset(y: 28)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if isHovered {
                        withAnimation(.easeIn(duration: 0.1)) { showTooltip = true }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.08)) { showTooltip = false }
            }
        }
    }

    private var tooltipView: some View {
        // 将 "名称 (快捷键)" 拆成两行显示
        let parts = tooltip.components(separatedBy: " (")
        let name = parts[0]
        let shortcut = parts.count > 1 ? String(parts[1].dropLast()) : nil

        return VStack(alignment: .leading, spacing: 1) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#cccccc"))
            if let sc = shortcut {
                Text(sc)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#858585"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: "#2d2d30"))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color(hex: "#454545"), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
        .fixedSize()
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
