# DevMac++ 设计文档

**日期**: 2026-03-18
**版本**: 1.0
**目标**: 为 macOS 复刻 Orwell Dev-C++ 5.11，用于算法竞赛训练

## 项目概述

DevMac++ 是 Orwell Dev-C++ 5.11 的 macOS 原生复刻版本，专为算法竞赛选手设计。核心原则是**不提供 Windows 版本没有的功能**，确保训练环境与真实竞赛环境一致。

### 核心特性

- 完整复刻 Dev-C++ 5.11 的界面布局和功能
- 深色主题 + macOS 原生毛玻璃效果
- 纯文本编辑器（无智能补全，只有基础语法高亮）
- GCC 编译器支持（固定 C++11 标准）
- 完整 GDB 调试功能（断点、单步、变量查看、调用栈）
- 自定义代码模板系统
- C/C++ API 帮助文档

## 技术栈

- **UI 框架**: Swift + SwiftUI
- **编辑器**: Monaco Editor（WKWebView 嵌入）
- **编译器**: GCC（通过 Homebrew 安装）
- **调试器**: GDB（通过 Homebrew 安装）
- **图标**: SF Symbols / 自定义 SVG
- **毛玻璃效果**: SwiftUI `.background(.ultraThinMaterial)`

## 界面设计

### 整体布局

```
┌─────────────────────────────────────────────────────┐
│ 菜单栏（macOS 原生）                                  │
│ 文件 编辑 搜索 查看 项目 执行 工具 窗口 帮助            │
├─────────────────────────────────────────────────────┤
│ 工具栏第一行（毛玻璃背景）                             │
│ [新建][打开][保存][另存为][关闭] | [打印] |            │
│ [剪切][复制][粘贴] | [撤销][重做] | [查找][替换]        │
├─────────────────────────────────────────────────────┤
│ 工具栏第二行（毛玻璃背景）                             │
│ [编译][运行][编译运行][重新编译][清理] |                │
│ [调试][暂停][停止][单步进入][单步跳过][单步跳出]         │
├──────────┬──────────────────────────────────────────┤
│          │ 文件标签栏                                 │
│          │ [未保存.cpp ●] [×]                         │
│ 左侧边栏  ├──────────────────────────────────────────┤
│          │                                          │
│ 非调试:   │                                          │
│ [项目]    │        Monaco Editor                     │
│ [类]      │        (代码编辑区)                       │
│          │                                          │
│ 调试时:   │                                          │
│ [监视]    │                                          │
│ [局部]    │                                          │
│ [栈]      │                                          │
│          │                                          │
├──────────┴──────────────────────────────────────────┤
│ 底部面板（毛玻璃背景）                                 │
│ [编译日志] [编译结果] [调试] [查找结果]                 │
│                                                     │
│ (显示编译输出、错误信息、调试输出等)                    │
├─────────────────────────────────────────────────────┤
│ 状态栏                                               │
│ 第 5 行，第 5 列 | 插入 | 1.2 KB | C++               │
└─────────────────────────────────────────────────────┘
```

### 视觉风格

- **主题**: 深色主题（类似 VS Code Dark+）
- **背景**:
  - 主编辑区: `#1e1e1e`
  - 工具栏/侧边栏/底部面板: `rgba(45, 45, 48, 0.95)` + 毛玻璃效果
- **文字**:
  - 主文字: `#d4d4d4`
  - 次要文字: `#ccc`
  - 行号: `#858585`
- **按钮**:
  - 普通按钮: 透明背景，悬停时 `rgba(255,255,255,0.1)`
  - 运行按钮: 绿色 `#4caf50`
  - 编译运行按钮: 橙色 `#ff9800`
  - 调试按钮: 蓝色 `#2196f3`
- **图标**: 使用 SF Symbols 或自定义 SVG，不使用 emoji

### 文件修改标记

- 未保存的文件在标签上显示小圆点 `●`（现代化设计）
- 保存后圆点消失

## 功能设计

### 1. 编辑器功能

**Monaco Editor 配置**（纯文本模式）:
```javascript
{
  language: 'cpp',
  theme: 'vs-dark',

  // 禁用所有智能功能
  quickSuggestions: false,
  suggestOnTriggerCharacters: false,
  acceptSuggestionOnEnter: 'off',
  tabCompletion: 'off',
  wordBasedSuggestions: false,
  parameterHints: { enabled: false },
  validate: false,

  // 保留基础功能
  lineNumbers: 'on',
  glyphMargin: true,  // 显示断点
  folding: false,
  minimap: { enabled: false }
}
```

**支持的功能**:
- C++ 语法高亮
- 行号显示
- 断点标记（左侧边栏点击切换）
- 基础编辑操作（剪切/复制/粘贴/撤销/重做）
- 查找/替换

**不支持的功能**:
- 代码补全
- 实时错误检查
- 代码折叠
- Minimap
- 参数提示

### 2. 编译功能

**编译命令**:
```bash
# 普通编译（Cmd+F11）
g++ -std=c++11 -o output_file source_file.cpp

# 调试编译（Cmd+F8）
g++ -std=c++11 -g -o output_file source_file.cpp
```

**编译流程**:
1. 检查文件是否保存，未保存则自动保存
2. 切换到"编译日志"标签
3. 调用 GCC 编译
4. 实时显示编译输出
5. 编译成功 → 切换到"编译结果"标签，显示成功信息
6. 编译失败 → 切换到"编译结果"标签，显示错误（可点击跳转）

**错误跳转**:
- 解析 GCC 错误信息中的文件名和行号（格式：`file.cpp:15:10: error: ...`）
- 在"编译结果"标签页中，错误行显示为可点击的链接样式
- 点击错误行触发：
  1. 编辑器跳转到对应行
  2. 高亮该行（背景色变化）
  3. 光标定位到错误列（如果有列号信息）

### 3. 运行功能

**运行流程**:
1. 检查是否已编译，未编译则先编译
2. 使用 AppleScript 启动 Terminal.app 并执行程序
3. 终端窗口显示程序输出
4. 程序结束后显示"按任意键继续"（通过在命令末尾添加 `read` 实现）

**终端窗口实现**:
```applescript
tell application "Terminal"
  do script "cd /path/to/output && ./program; echo '\n程序已结束'; read -n 1 -s -r -p '按任意键继续...'"
  activate
end tell
```

**快捷键**:
- **Cmd+F11**: 编译（只编译，不运行）
- **Cmd+F10**: 运行（如果未编译则先编译）
- **Cmd+F9**: 编译运行（一步到位）

### 4. 调试功能

**调试器**: GDB（通过 GDB/MI 协议通信）

**调试流程**:
1. 用户点击"调试"（Cmd+F8）
2. 检查是否已用 `-g` 编译，未编译则重新编译
3. 启动 GDB 进程
4. 设置所有断点
5. `isDebugging = true`，左侧边栏切换到调试面板
6. 运行到第一个断点或 main 函数
7. 更新调试状态（当前行、局部变量、调用栈、监视变量）

**调试操作**:
- **Cmd+F11**: 单步进入（Step Into）
- **Cmd+F10**: 单步跳过（Step Over）
- **Cmd+Shift+F11**: 单步跳出（Step Out）
- **Cmd+F9**: 继续执行（Continue）
- **Cmd+F2**: 停止调试（Stop）
- **Cmd+F5**: 切换断点（Toggle Breakpoint）

**调试面板**（左侧边栏）:

**监视窗口**:
- 显示用户添加的监视变量
- 支持表达式（如 `arr[0]`, `n+1`）
- 点击"+ 添加监视"添加新变量

**局部变量窗口**:
- 自动显示当前作用域的所有局部变量
- 实时更新变量值

**调用栈窗口**:
- 显示函数调用链
- 点击栈帧可以查看对应位置的变量

### 5. 代码模板系统

**默认模板**:
- 只提供"空白文件"一个默认模板

**自定义模板**:
- 用户可以保存当前代码为模板
- 模板存储在 `~/Library/Application Support/DevMac++/templates.json`
- 新建文件时可以选择自定义模板

**模板管理**:
- 工具 → 代码模板管理
- 可以添加/编辑/删除自定义模板

### 6. 帮助文档

**实现方式**:
- 打包 cppreference.com 离线版本或原版 Dev-C++ 帮助文档
- 使用 WKWebView 在独立窗口显示
- 支持搜索和索引

**菜单项**:
- 帮助 → C/C++ 参考手册
- 帮助 → 关于 DevMac++

### 7. 查找/替换

**查找**（Cmd+F）:
- 在编辑器顶部显示查找栏
- 支持：区分大小写、全词匹配、正则表达式
- 上一个/下一个匹配

**替换**（Cmd+H）:
- 在查找栏下方显示替换栏
- 替换当前/替换全部

**查找结果**:
- 显示在底部"查找结果"标签页

### 8. 编译器选项

**固定选项**:
- C++ 标准: `c++11`（不可更改）

**可配置选项**:
- 优化级别: `-O0` / `-O1` / `-O2` / `-O3`
- 警告选项: `-Wall` / `-Wextra` / `-Werror`
- 附加参数: 自定义文本框

**菜单**: 工具 → 编译器选项

### 9. 编辑器选项

**可配置项**:
- 字体大小: 默认 13
- 字体: 默认 Monaco
- Tab 大小: 默认 4
- Tab 键行为: 插入空格 / 插入制表符
- 显示行号: 默认开启
- 显示空白字符: 默认关闭
- 自动换行: 默认关闭

**菜单**: 工具 → 编辑器选项

## 技术架构

### 应用状态管理

```swift
@MainActor
class AppState: ObservableObject {
  // 编辑器状态
  @Published var currentFile: FileInfo?
  @Published var fileContent: String = ""
  @Published var cursorPosition: CursorPosition
  @Published var isModified: Bool = false
  @Published var fileSize: Int = 0

  // 编译状态
  @Published var isCompiling: Bool = false
  @Published var compileLog: String = ""
  @Published var compileResult: CompileResult?

  // 调试状态
  @Published var isDebugging: Bool = false
  @Published var breakpoints: Set<Int> = []
  @Published var currentDebugLine: Int?
  @Published var watchVariables: [WatchVariable] = []
  @Published var localVariables: [Variable] = []
  @Published var callStack: [StackFrame] = []

  // UI 状态
  @Published var selectedBottomTab: BottomTab
  @Published var selectedSidebarTab: SidebarTab
  @Published var sidebarWidth: CGFloat = 200
  @Published var bottomPanelHeight: CGFloat = 150
}
```

### 核心服务

**CompilerService**:
- 负责调用 GCC 编译
- 解析编译输出和错误信息
- 管理编译选项

**DebuggerService**:
- 负责启动和管理 GDB 进程
- 通过 GDB/MI 协议通信
- 处理断点、单步、变量查看等操作

**TemplateManager**:
- 管理代码模板
- 加载/保存用户自定义模板

**HelpDocumentManager**:
- 管理帮助文档
- 提供搜索和导航功能

### Swift ↔ JavaScript 通信

**Swift 调用 JS**（设置断点标记）:
```swift
webView.evaluateJavaScript("""
  editor.deltaDecorations([], [{
    range: new monaco.Range(\(line), 1, \(line), 1),
    options: {
      isWholeLine: true,
      className: 'breakpoint-line',
      glyphMarginClassName: 'breakpoint-glyph'
    }
  }]);
""")
```

**JS 调用 Swift**（用户点击行号）:
```javascript
// JS 端
window.webkit.messageHandlers.breakpointToggle.postMessage({
  line: lineNumber
});

// Swift 端
func userContentController(_ userContentController: WKUserContentController,
                          didReceive message: WKScriptMessage) {
  if message.name == "breakpointToggle" {
    let line = message.body["line"] as! Int
    toggleBreakpoint(at: line)
  }
}
```

## 快捷键列表

| 功能 | 快捷键 |
|------|--------|
| 新建文件 | Cmd+N |
| 打开文件 | Cmd+O |
| 保存 | Cmd+S |
| 另存为 | Cmd+Shift+S |
| 关闭文件 | Cmd+W |
| 退出 | Cmd+Q |
| 撤销 | Cmd+Z |
| 重做 | Cmd+Shift+Z |
| 剪切 | Cmd+X |
| 复制 | Cmd+C |
| 粘贴 | Cmd+V |
| 查找 | Cmd+F |
| 替换 | Cmd+H |
| 跳转到行 | Cmd+G |
| 编译 | Cmd+F11 |
| 运行 | Cmd+F10 |
| 编译运行 | Cmd+F9 |
| 调试 | Cmd+F8 |
| 单步进入 | Cmd+F11（调试时）|
| 单步跳过 | Cmd+F10（调试时）|
| 单步跳出 | Cmd+Shift+F11 |
| 继续执行 | Cmd+F9（调试时）|
| 停止调试 | Cmd+F2 |
| 切换断点 | Cmd+F5 |

**快捷键状态机**：
- 非调试模式：Cmd+F9/F10/F11 执行编译/运行操作
- 调试模式（`isDebugging == true`）：相同快捷键自动切换为调试操作
- 状态切换：点击"调试"按钮或 Cmd+F8 进入调试模式，点击"停止"或 Cmd+F2 退出调试模式

## 首次启动设置

### 环境检查

应用首次启动时检查：
1. Homebrew 是否安装
2. GCC 是否安装（`/opt/homebrew/bin/g++`）
3. GDB 是否安装（`/opt/homebrew/bin/gdb`）
4. GDB 是否已签名（macOS 要求）

### 设置向导

如果检测到缺失的工具，显示设置向导：

**步骤 1: 安装 Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**步骤 2: 安装 GCC**
```bash
brew install gcc
```

**步骤 3: 安装 GDB**
```bash
brew install gdb
```

**步骤 4: 签名 GDB**

GDB 在 macOS 上需要代码签名才能调试进程。设置向导提供两种方式：

**方式 1: 自动化脚本**（推荐）
- 应用内置签名脚本，自动创建证书并签名 GDB
- 需要用户输入管理员密码

**方式 2: 手动步骤**
- 在设置向导中显示详细步骤文档
- 包含：创建证书、信任证书、签名 GDB 的完整命令
- 提供"复制命令"按钮方便用户操作

## 错误处理

### 错误类型

```swift
enum AppError: LocalizedError {
  case gccNotFound
  case gdbNotFound
  case compileFailed(String)
  case debuggerCrashed
  case fileNotSaved
  case fileReadError(String)
  case fileWriteError(String)
  case gdbNotSigned
}
```

### 错误显示

- 编译错误：显示在"编译结果"标签页，可点击跳转
- 运行时错误：显示在终端窗口
- 调试器错误：显示在"调试"标签页
- 系统错误：使用 macOS 原生 Alert 对话框

## 项目结构

```
DevMac++/
├── DevMac++.xcodeproj
├── DevMac++/
│   ├── App/
│   │   ├── DevMacApp.swift          # 应用入口
│   │   └── AppState.swift           # 全局状态
│   ├── Views/
│   │   ├── ContentView.swift        # 主窗口
│   │   ├── MenuBar.swift            # 菜单栏
│   │   ├── ToolbarView.swift        # 工具栏
│   │   ├── SidebarView.swift        # 左侧边栏
│   │   ├── EditorView.swift         # 编辑器容器
│   │   ├── MonacoEditorView.swift   # Monaco Editor (WKWebView)
│   │   ├── BottomPanelView.swift    # 底部面板
│   │   └── StatusBarView.swift      # 状态栏
│   ├── Services/
│   │   ├── CompilerService.swift    # 编译服务
│   │   ├── DebuggerService.swift    # 调试服务
│   │   ├── TemplateManager.swift    # 模板管理
│   │   └── HelpDocumentManager.swift # 帮助文档
│   ├── Models/
│   │   ├── FileInfo.swift
│   │   ├── CompileResult.swift
│   │   ├── DebugState.swift
│   │   └── CodeTemplate.swift
│   ├── Resources/
│   │   ├── monaco/                  # Monaco Editor 资源
│   │   ├── icons/                   # 图标资源
│   │   └── help/                    # 帮助文档
│   └── Info.plist
└── README.md
```

## 开发计划

### Phase 1: 基础框架（2-3 周）
- SwiftUI 窗口结构
- Monaco Editor 集成
- 基础文件操作（新建/打开/保存）
- 状态栏和工具栏

### Phase 2: 编译功能（1-2 周）
- GCC 集成
- 编译日志显示
- 错误解析和跳转
- 编译选项配置

### Phase 3: 调试功能（2-3 周）
- GDB 集成
- 断点管理
- 单步执行
- 变量查看
- 调用栈显示

### Phase 4: 辅助功能（1-2 周）
- 代码模板系统
- 查找/替换
- 帮助文档
- 编辑器选项

### Phase 5: 优化和测试（1-2 周）
- 性能优化
- 毛玻璃效果调优
- 图标替换（去除 emoji）
- 完整测试

## 与原版的差异

### 保持一致的部分
- 界面布局和功能
- 编译器行为（GCC + C++11）
- 调试功能（GDB）
- 快捷键逻辑（Cmd 替代 Ctrl）
- 单文件工作流

### 现代化改进
- 深色主题 + 毛玻璃效果
- 文件修改标记用圆点代替星号
- macOS 原生窗口和控件
- 更好的图标（SF Symbols）

### 技术限制
- 使用 Monaco Editor 而非原生文本控件
- GDB 需要签名（macOS 安全限制）
- 终端窗口行为可能略有不同

## 总结

DevMac++ 是一个忠实于原版 Dev-C++ 5.11 的 macOS 复刻版本，专为算法竞赛选手设计。通过使用 Swift + SwiftUI + Monaco Editor 的技术栈，在保持原版功能和体验的同时，提供了现代化的视觉效果和 macOS 原生体验。

核心设计原则是**不添加原版没有的功能**，确保训练环境与真实竞赛环境一致，避免在比赛时因功能差异而不适应。
