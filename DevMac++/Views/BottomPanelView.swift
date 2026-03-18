import SwiftUI

struct BottomPanelView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var debuggerService: DebuggerService

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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        switch appState.selectedBottomTab {
                        case .compileLog:
                            Text(appState.compileLog.isEmpty ? "就绪" : appState.compileLog)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#cccccc"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("compileLog")
                        case .compileResult:
                            VStack(alignment: .leading, spacing: 2) {
                                if appState.compileSuccess {
                                    Text("编译成功")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Color(hex: "#4caf50"))
                                } else if !appState.compileErrors.isEmpty {
                                    ForEach(appState.compileErrors) { error in
                                        Text("\(error.file):\(error.line):\(error.column): \(error.message)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Color(hex: "#f44336"))
                                            .textSelection(.enabled)
                                    }
                                } else {
                                    Text(appState.compileOutput.isEmpty ? "" : appState.compileOutput)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Color(hex: "#cccccc"))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        case .debug:
                            Text(debuggerService.debugOutput.isEmpty ? "调试输出将显示在这里" : debuggerService.debugOutput)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(debuggerService.debugOutput.isEmpty ? Color(hex: "#858585") : Color(hex: "#cccccc"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id("debugOutput")
                        case .findResults:
                            Text("查找结果将显示在这里")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#858585"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#252526"))
                .onChange(of: debuggerService.debugOutput) { _ in
                    withAnimation { proxy.scrollTo("debugOutput", anchor: .bottom) }
                }
                .onChange(of: appState.compileLog) { _ in
                    withAnimation { proxy.scrollTo("compileLog", anchor: .bottom) }
                }
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
