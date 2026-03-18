import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            ToolbarView()
                .background(.ultraThinMaterial)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 主内容区（侧边栏 + 编辑器）
            HSplitView {
                SidebarView()
                    .frame(minWidth: 150, idealWidth: appState.sidebarWidth, maxWidth: 400)
                    .background(.ultraThinMaterial)

                // 编辑器占位（Plan 2 实现）
                EditorPlaceholderView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 底部面板
            BottomPanelView()
                .frame(height: appState.bottomPanelHeight)
                .background(.ultraThinMaterial)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 状态栏
            StatusBarView()
                .background(.ultraThinMaterial)
        }
        .background(Color(hex: "#1e1e1e"))
        .preferredColorScheme(.dark)
    }
}

// 编辑器占位视图（Plan 2 替换）
struct EditorPlaceholderView: View {
    var body: some View {
        ZStack {
            Color(hex: "#1e1e1e")
            Text("编辑器加载中...")
                .foregroundColor(Color(hex: "#858585"))
                .font(.system(size: 13, design: .monospaced))
        }
    }
}

// Color hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
