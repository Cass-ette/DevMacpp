# 编译器服务实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 GCC 编译器集成，支持编译、运行、编译运行，以及错误解析和跳转功能

**Architecture:** 使用 Swift `Process` API 调用 GCC/GDB，子进程输出实时流式读取到 AppState。编译选项固定 `-std=c++11`，调试编译额外加 `-g`

**Tech Stack:** Swift Process, GDB/MI protocol

---

## Chunk 1: 编译器核心

### Task 1: CompilerService 实现

**Files:**
- Create: `DevMac++/Services/CompilerService.swift`
- Create: `DevMac++/Models/CompileResult.swift`

- [ ] **Step 1: 创建 CompileResult 模型**

```swift
import Foundation

struct CompileError: Identifiable {
    let id = UUID()
    let file: String
    let line: Int
    let column: Int
    let message: String
}

struct CompileResult {
    let success: Bool
    let output: String
    let errors: [CompileError]
    let executablePath: String?
}
```

- [ ] **Step 2: 创建 CompilerService.swift**

```swift
import Foundation

class CompilerService: ObservableObject {
    @Published var isCompiling = false
    @Published var compileLog = ""
    @Published var lastResult: CompileResult?
    
    // GCC 路径
    var gccPath: String {
        // 优先使用 Homebrew 安装的 GCC
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/g++-13") {
            return "/opt/homebrew/bin/g++-13"
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/g++") {
            return "/opt/homebrew/bin/g++"
        }
        return "g++"  // fallback to PATH
    }
    
    var gdbPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gdb") {
            return "/opt/homebrew/bin/gdb"
        }
        return "gdb"  // fallback to PATH
    }
    
    func compile(filePath: String, withDebug: Bool = false) async throws -> CompileResult {
        isCompiling = true
        defer { isCompiling = false }
        
        // 确定输出路径
        let outputPath = (filePath as NSString).deletingPathExtension + "_run"
        
        // 构建命令
        var args = ["-std=c++11", "-o", outputPath, filePath]
        if withDebug {
            args.append("-g")
        }
        
        compileLog = "Compiling \(filePath)...\n"
        compileLog += "Compiler: \(gccPath)\n"
        compileLog += "Command: g++ \(args.joined(separator: " "))\n\n"
        
        let result = try await runProcess(executable: gccPath, arguments: args)
        
        compileLog += result.output
        
        let errors = parseErrors(result.output, filePath: filePath)
        
        let success = result.returnCode == 0
        
        if success {
            compileLog += "\nCompilation successful."
        } else {
            compileLog += "\nCompilation failed."
        }
        
        let compileResult = CompileResult(
            success: success,
            output: result.output,
            errors: errors,
            executablePath: success ? outputPath : nil
        )
        
        lastResult = compileResult
        return compileResult
    }
    
    func compileOnly(filePath: String) async throws -> CompileResult {
        return try await compile(filePath: filePath, withDebug: false)
    }
    
    func compileForDebug(filePath: String) async throws -> CompileResult {
        return try await compile(filePath: filePath, withDebug: true)
    }
    
    private func runProcess(executable: String, arguments: [String]) async throws -> (output: String, returnCode: Int32) {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // 非阻塞读取输出
            var outputData = Data()
            var errorData = Data()
            
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errorData.append(data)
                }
            }
            
            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                let combined = output + (errorOutput.isEmpty ? "" : "\n" + errorOutput)
                
                continuation.resume(returning: (combined, process.terminationStatus))
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseErrors(_ output: String, filePath: String) -> [CompileError] {
        var errors: [CompileError] = []
        
        // GCC 错误格式: file.cpp:line:column: message
        let pattern = #"(.+?):(\d+):(\d+):\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return errors
        }
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    let file = String(line[Range(match.range(at: 1), in: line)!])
                    let lineNum = Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                    let column = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
                    let message = String(line[Range(match.range(at: 4), in: line)!])
                    
                    errors.append(CompileError(
                        file: file,
                        line: lineNum,
                        column: column,
                        message: message
                    ))
                }
            }
        }
        
        return errors
    }
}
```

- [ ] **Step 3: 注册 CompilerService 到 AppState**

在 `DevMacApp.swift` 中：

```swift
@StateObject private var compilerService = CompilerService()
```

传递给 ContentView：

```swift
ContentView()
    .environmentObject(appState)
    .environmentObject(fileService)
    .environmentObject(compilerService)
```

- [ ] **Step 4: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add CompilerService with GCC integration"
```

---

### Task 2: 编译选项面板

**Files:**
- Create: `DevMac++/Models/CompilerOptions.swift`
- Modify: `DevMac++/Services/CompilerService.swift`

- [ ] **Step 1: 创建编译器选项模型**

```swift
import Foundation

struct CompilerOptions {
    // 固定 C++11，不提供更改选项
    static let standard = "c++11"
    
    var optimizationLevel: String = "-O0"  // -O0, -O1, -O2, -O3
    var enableWall: Bool = false
    var enableWextra: Bool = false
    var additionalFlags: String = ""
    
    func toArguments() -> [String] {
        var args: [String] = ["-std=\(CompilerOptions.standard)"]
        args.append(optimizationLevel)
        if enableWall { args.append("-Wall") }
        if enableWextra { args.append("-Wextra") }
        if !additionalFlags.isEmpty {
            args.append(contentsOf: additionalFlags.components(separatedBy: " "))
        }
        return args
    }
}
```

- [ ] **Step 2: 更新 CompilerService 使用选项**

修改 `compile` 方法，使用 `CompilerOptions`：

```swift
func compile(filePath: String, withDebug: Bool = false, options: CompilerOptions = CompilerOptions()) async throws -> CompileResult {
    // ...
    var args = options.toArguments()
    if withDebug {
        args.append("-g")
    }
    args.append(contentsOf: ["-o", outputPath, filePath])
    // ...
}
```

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add compiler options model"
```

---

## Chunk 2: 编译 UI 集成

### Task 3: 编译菜单和状态更新

**Files:**
- Modify: `DevMac++/Views/AppMenuCommands.swift`
- Modify: `DevMac++/Views/BottomPanelView.swift`

- [ ] **Step 1: 更新菜单命令连接编译**

修改 `AppMenuCommands.swift`：

```swift
struct AppMenuCommands: Commands {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileService: FileService
    @EnvironmentObject var compilerService: CompilerService
    
    var body: some Commands {
        CommandMenu("执行") {
            Button("编译") {
                Task {
                    if let path = appState.currentFilePath {
                        try? await compilerService.compileOnly(filePath: path)
                        appState.selectedBottomTab = .compileLog
                    }
                }
            }
            .keyboardShortcut(.f11, modifiers: .command)
            
            Button("运行") {
                Task {
                    // 先编译再运行
                }
            }
            .keyboardShortcut(.f10, modifiers: .command)
            
            Button("编译运行") {
                Task {
                    await compileAndRun()
                }
            }
            .keyboardShortcut(.f9, modifiers: .command)
            
            Divider()
            
            Button("调试") {
                Task {
                    // 编译并启动调试
                }
            }
            .keyboardShortcut(.f8, modifiers: .command)
            
            Button("停止调试") {
                // 停止调试
            }
            .keyboardShortcut(.f2, modifiers: .command)
            
            Divider()
            
            Button("切换断点") {
                // 在当前行切换断点
            }
            .keyboardShortcut(.f5, modifiers: .command)
        }
    }
    
    @MainActor
    func compileAndRun() async {
        guard let path = appState.currentFilePath else { return }
        
        do {
            let result = try await compilerService.compileOnly(filePath: path)
            appState.selectedBottomTab = .compileLog
            
            if result.success, let exePath = result.executablePath {
                // 运行程序
                await runExecutable(path: exePath)
            }
        } catch {
            appState.compileOutput = "Error: \(error.localizedDescription)"
            appState.selectedBottomTab = .compileResult
        }
    }
    
    @MainActor
    func runExecutable(path: String) async {
        // 使用 AppleScript 启动 Terminal 运行
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
```

- [ ] **Step 2: 更新 BottomPanelView 显示编译日志**

修改 `BottomPanelView.swift` 的内容区，添加可点击的错误跳转：

```swift
case .compileResult:
    VStack(alignment: .leading, spacing: 2) {
        if appState.compileErrors.isEmpty {
            if appState.compileSuccess {
                Text("编译成功")
                    .foregroundColor(Color(hex: "#4caf50"))
            } else {
                Text("编译失败")
                    .foregroundColor(Color(hex: "#f44336"))
            }
        } else {
            ForEach(appState.compileErrors) { error in
                Text("\(error.file):\(error.line):\(error.column): \(error.message)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#f44336"))
                    .textSelection(.enabled)
                    .onTapGesture {
                        appState.goToError(line: error.line, column: error.column)
                    }
            }
        }
    }
```

- [ ] **Step 3: 添加编译错误到 AppState**

在 `AppState.swift` 中添加：

```swift
@Published var compileErrors: [CompileError] = []
@Published var compileSuccess: Bool = false
```

添加方法：

```swift
func goToError(line: Int, column: Int) {
    // 通过 MonacoEditorView 的 coordinator 跳转到指定行
}
```

- [ ] **Step 4: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: integrate compiler with menu and bottom panel"
```

---

### Task 4: 首次启动 GCC 检测

**Files:**
- Create: `DevMac++/Services/SetupService.swift`

- [ ] **Step 1: 创建 SetupService 检测 GCC/GDB**

```swift
import Foundation

class SetupService: ObservableObject {
    @Published var gccInstalled = false
    @Published var gdbInstalled = false
    @Published var gdbSigned = false
    @Published var showSetupGuide = false
    
    func checkEnvironment() {
        gccInstalled = checkCommand("g++")
        gdbInstalled = checkCommand("gdb")
        
        // GDB 签名检测
        if gdbInstalled {
            let result = runCommand("codesign", args: ["-dv", gdbPath])
            gdbSigned = result.contains("valid")
        }
        
        if !gccInstalled || !gdbInstalled || !gdbSigned {
            showSetupGuide = true
        }
    }
    
    private func checkCommand(_ cmd: String) -> Bool {
        let result = runCommand("which", args: [cmd])
        return !result.isEmpty
    }
    
    private func runCommand(_ cmd: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [cmd]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
```

- [ ] **Step 2: 在 App 启动时检测**

在 `DevMacApp` 中：

```swift
@StateObject private var setupService = SetupService()

.onAppear {
    setupService.checkEnvironment()
}
```

- [ ] **Step 3: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add GCC/GDB environment detection on startup"
```

---

## 完成标准

Plan 3 完成后，应用应该：

- [ ] GCC 编译功能正常（Cmd+F11）
- [ ] 编译日志实时显示
- [ ] 编译错误可点击跳转
- [ ] 编译成功/失败状态正确显示
- [ ] 编译运行正常（Cmd+F9）
- [ ] 终端窗口弹出显示程序输出
- [ ] GCC/GDB 首次启动检测正常
- [ ] 编译成功，推送到 GitHub

**下一步：** Plan 4 - 调试器服务（GDB 集成）
