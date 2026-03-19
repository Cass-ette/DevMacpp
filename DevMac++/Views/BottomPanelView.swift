import SwiftUI

struct BottomPanelView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService
    @EnvironmentObject var runtimeService: RuntimeService

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                ForEach(BottomTab.allCases, id: \.self) { tab in
                    BottomTabButton(
                        title: tab.rawValue,
                        selected: appState.selectedBottomTab == tab
                    ) {
                        appState.selectedBottomTab = tab
                    }
                }
                Spacer()
            }
            .background(Color(hex: "#2d2d30"))

            Divider().background(Color(hex: "#3e3e42"))

            // 内容区
            Group {
                switch appState.selectedBottomTab {
                case .compileLog:
                    CompileLogView()
                case .compileResult:
                    CompileResultView()
                case .runtime:
                    RuntimeConsoleView()
                case .debug:
                    DebugOutputView()
                }
            }
        }
    }
}

struct CompileLogView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(appState.compileLog.isEmpty ? "就绪" : appState.compileLog)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(appState.compileLog.isEmpty ? Color(hex: "#858585") : Color(hex: "#cccccc"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
                    .id("compileLog")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#252526"))
            .onChange(of: appState.compileLog) { _ in
                withAnimation { proxy.scrollTo("compileLog", anchor: .bottom) }
            }
        }
    }
}

struct CompileResultView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if appState.compileSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#4caf50"))
                        Text("编译成功")
                            .foregroundColor(Color(hex: "#4caf50"))
                    }
                    .font(.system(size: 12, design: .monospaced))
                }

                if !appState.compileErrors.isEmpty {
                    ForEach(appState.compileErrors) { error in
                        Text("\(error.file):\(error.line):\(error.column): \(error.message)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#f44336"))
                            .textSelection(.enabled)
                    }
                }

                if !appState.compileOutput.isEmpty {
                    Text(appState.compileOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccccc"))
                        .textSelection(.enabled)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#252526"))
    }
}

struct RuntimeConsoleView: View {
    @EnvironmentObject var runtimeService: RuntimeService
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 输出区域
            ScrollViewReader { proxy in
                ScrollView {
                    Text(runtimeService.output.isEmpty ? "运行输出将显示在这里..." : runtimeService.output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(runtimeService.output.isEmpty ? Color(hex: "#858585") : Color(hex: "#cccccc"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("output")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1e1e1e"))
                .onChange(of: runtimeService.output) { _ in
                    withAnimation { proxy.scrollTo("output", anchor: .bottom) }
                }
            }

            // 状态栏
            HStack {
                if runtimeService.isRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#4caf50"))
                            .frame(width: 8, height: 8)
                        Text("运行中")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#4caf50"))
                    }
                } else if runtimeService.isFinished {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#858585"))
                            .frame(width: 8, height: 8)
                        Text("已结束")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#858585"))
                    }
                } else {
                    Text("就绪")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#858585"))
                }

                Spacer()

                if runtimeService.isRunning {
                    Button("停止") {
                        runtimeService.stop()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#f44336"))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#2d2d30"))

            // 多行输入区域（支持粘贴样例）
            HStack(alignment: .bottom, spacing: 0) {
                TextEditor(text: $inputText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 64)
                    .disabled(!runtimeService.isRunning)

                Button("发送") {
                    sendInput()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(runtimeService.isRunning && !inputText.isEmpty ? Color(hex: "#4caf50") : Color(hex: "#555555"))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .disabled(!runtimeService.isRunning || inputText.isEmpty)
            }
            .padding(.horizontal, 8)
            .background(Color(hex: "#1a1a1a"))
            .overlay(
                Rectangle()
                    .fill(Color(hex: "#3e3e42"))
                    .frame(height: 1),
                alignment: .top
            )
        }
    }

    private func sendInput() {
        guard !inputText.isEmpty else { return }
        runtimeService.sendAll(inputText)
        inputText = ""
    }
}

struct DebugOutputView: View {
    @EnvironmentObject var debuggerService: DebuggerService
    @State private var inputText: String = ""
    @State private var isSending: Bool = false  // 防止重复发送

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(debuggerService.debugOutput.isEmpty ? "调试输出将显示在这里" : debuggerService.debugOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(debuggerService.debugOutput.isEmpty ? Color(hex: "#858585") : Color(hex: "#cccccc"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("debugOutput")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#252526"))
                .onChange(of: debuggerService.debugOutput) { _ in
                    withAnimation { proxy.scrollTo("debugOutput", anchor: .bottom) }
                }
            }

            // 调试期间始终显示输入框
            if debuggerService.isDebugging {
                HStack(spacing: 6) {
                    Text("stdin:")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#4caf50"))
                    TextField("输入后回车发送", text: $inputText)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onSubmit {
                            guard !inputText.isEmpty, !isSending else { return }
                            let text = inputText
                            inputText = ""
                            isSending = true
                            // 按换行拆分，每行单独发送（最后一行的 autoContinue 由用户按继续按钮触发）
                            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                            Task {
                                for (i, line) in lines.enumerated() {
                                    debuggerService.sendInput(line, autoContinue: false)
                                    if i < lines.count - 1 {
                                        try? await Task.sleep(nanoseconds: 50_000_000)
                                    }
                                }
                                isSending = false
                            }
                        }
                    Button("继续") {
                        Task {
                            await debuggerService.continue_()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!debuggerService.isDebugging)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#2d2d30"))
            }
        }
    }
}


struct BottomTabButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(selected ? .white : Color(hex: "#cccccc"))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? Color(hex: "#1e1e1e") : Color.clear)
                .overlay(
                    Rectangle()
                        .fill(selected ? Color(hex: "#007acc") : Color.clear)
                        .frame(height: 2),
                    alignment: .top
                )
        }
        .buttonStyle(.plain)
    }
}
