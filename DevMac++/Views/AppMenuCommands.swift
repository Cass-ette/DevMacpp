import SwiftUI
import AppKit

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
    func runExecutable(path: String) async {
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
