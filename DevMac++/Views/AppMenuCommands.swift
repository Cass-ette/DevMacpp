import SwiftUI
import AppKit

struct AppMenuCommands: Commands {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileService: FileService
    @EnvironmentObject var compilerService: CompilerService

    var body: some Commands {
        // 文件菜单
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
                fileService.saveFile(appState: appState)
            }
                .keyboardShortcut("s", modifiers: .command)
            Button("另存为...") {
                fileService.saveAs(appState: appState)
            }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("关闭") {
                // Can just call newFile for now
            }
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
            Button("编译") {
                Task { @MainActor in
                    guard let path = appState.currentFilePath else { return }
                    appState.selectedBottomTab = .compileLog
                    let result = try? await compilerService.compileOnly(filePath: path)
                    appState.compileErrors = result?.errors ?? []
                    appState.compileSuccess = result?.success ?? false
                    if result?.success == false {
                        appState.selectedBottomTab = .compileResult
                    }
                }
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F70B}")), modifiers: .command)

            Button("运行") {
                Task { @MainActor in
                    await compileAndRun()
                }
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F70A}")), modifiers: .command)

            Button("编译运行") {
                Task { @MainActor in
                    await compileAndRun()
                }
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F709}")), modifiers: .command)

            Divider()

            Button("调试") {
                // Implemented in Plan 4
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F708}")), modifiers: .command)

            Button("停止调试") {
                // Implemented in Plan 4
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F702}")), modifiers: .command)

            Divider()

            Button("切换断点") {
                // Implemented in Plan 4
            }
                .keyboardShortcut(KeyEquivalent(Character("\u{F705}")), modifiers: .command)
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

    @MainActor
    func compileAndRun() async {
        guard let path = appState.currentFilePath else { return }

        appState.selectedBottomTab = .compileLog
        let result = try? await compilerService.compileOnly(filePath: path)
        appState.compileErrors = result?.errors ?? []
        appState.compileSuccess = result?.success ?? false

        if result?.success == true, let exePath = result?.executablePath {
            appState.selectedBottomTab = .compileResult
            appState.compileOutput = "Running \(exePath)...\n"

            // 使用 AppleScript 启动 Terminal
            let directory = (exePath as NSString).deletingLastPathComponent
            let script = """
            tell application "Terminal"
                do script "cd \"\(directory)\" && './\((exePath as NSString).lastPathComponent)'; echo ''; read -n 1 -s -r -p '按任意键继续...'"
                activate
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        } else {
            appState.selectedBottomTab = .compileResult
            if let errors = result?.errors {
                var errorText = ""
                for err in errors {
                    errorText += "\(err.file):\(err.line):\(err.column): \(err.message)\n"
                }
                appState.compileOutput = errorText
            }
        }
    }
}
