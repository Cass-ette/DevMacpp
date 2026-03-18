import SwiftUI
import AppKit

struct AppMenuCommands: Commands {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileService: FileService
    @EnvironmentObject var compilerService: CompilerService
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some Commands {
        CommandMenu("文件") {
            Button("新建") {
                appState.showTemplatePicker = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开...") {
                fileService.openFile(appState: appState)
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("保存") {
                fileService.saveFile(appState: appState)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("另存为...") {
                fileService.saveAs(appState: appState)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("关闭") {
                // 关闭当前文件
                fileService.newFile(appState: appState)
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandMenu("编辑") {
            Button("撤销") {
                NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("重做") {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider()

            Button("剪切") {
                NSApp.sendAction(Selector(("cut:")), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("复制") {
                NSApp.sendAction(Selector(("copy:")), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("粘贴") {
                NSApp.sendAction(Selector(("paste:")), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)

            Divider()

            Button("全选") {
                NSApp.sendAction(Selector(("selectAll:")), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)
        }

        CommandMenu("执行") {
            Button("编译") {
                Task {
                    await compileOnly()
                }
            }
            .keyboardShortcut("\u{F70B}", modifiers: .command) // Cmd+F11

            Button("运行") {
                Task {
                    await runOnly()
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

        CommandMenu("帮助") {
            Button("C/C++ 参考手册") {
                if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "help") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("关于 DevMac++") {
                let alert = NSAlert()
                alert.messageText = "DevMac++"
                alert.informativeText = "版本 1.0\nmacOS 上的 Dev-C++ 复刻\n用于算法竞赛训练"
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }

    @MainActor
    func compileOnly() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }
        guard let path = appState.currentFilePath else { return }

        appState.compileLog = "正在编译...\n"
        appState.selectedBottomTab = .compileLog
        let result = try? await compilerService.compileOnly(filePath: path)
        appState.compileSuccess = result?.success ?? false
        appState.compileErrors = result?.errors ?? []
        appState.compileLog = result?.output ?? ""
    }

    @MainActor
    func runOnly() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }
        guard let path = appState.currentFilePath else { return }

        appState.compileLog = "正在编译...\n"
        appState.selectedBottomTab = .compileLog
        let result = try? await compilerService.compileOnly(filePath: path)
        if result?.success == true, let exePath = result?.executablePath {
            appState.compileLog = (result?.output ?? "") + "\n运行中...\n"
            await runExecutable(path: exePath)
        } else {
            appState.compileSuccess = false
            appState.compileErrors = result?.errors ?? []
            appState.compileLog = result?.output ?? ""
        }
    }

    @MainActor
    func compileAndRun() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }
        guard let path = appState.currentFilePath else { return }

        appState.compileLog = "正在编译...\n"
        appState.selectedBottomTab = .compileLog
        let result = try? await compilerService.compileOnly(filePath: path)
        appState.compileSuccess = result?.success ?? false
        appState.compileErrors = result?.errors ?? []
        appState.compileLog = result?.output ?? ""

        if result?.success == true, let exePath = result?.executablePath {
            appState.compileLog = (result?.output ?? "") + "\n运行中...\n"
            await runExecutable(path: exePath)
        }
    }

    @MainActor
    func startDebug() async {
        if appState.currentFilePath == nil {
            fileService.saveFile(appState: appState)
            if appState.currentFilePath == nil { return }
        }
        guard let path = appState.currentFilePath else { return }

        appState.compileLog = "正在编译（调试模式）...\n"
        appState.selectedBottomTab = .compileLog

        do {
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
                appState.isDebugging = true
                appState.selectedBottomTab = .debug
            }
        } catch {
            appState.compileLog = "调试错误: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileLog
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
