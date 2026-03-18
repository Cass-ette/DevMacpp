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
                case .findResults:
                    FindResultsView()
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
                    .foregroundColor(Color(hex: "#cccccc"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
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

            // 输入区域
            HStack(spacing: 8) {
                Text(">")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "#4caf50"))

                TextField("输入后按回车发送", text: $inputText)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .onSubmit {
                        sendInput()
                    }
                    .disabled(!runtimeService.isRunning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#252526"))
        }
    }

    private func sendInput() {
        guard !inputText.isEmpty else { return }
        runtimeService.sendLine(inputText)
        inputText = ""
    }
}

struct DebugOutputView: View {
    @EnvironmentObject var debuggerService: DebuggerService

    var body: some View {
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
    }
}

struct FindResultsView: View {
    var body: some View {
        Text("查找结果将显示在这里")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(hex: "#858585"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(Color(hex: "#252526"))
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
