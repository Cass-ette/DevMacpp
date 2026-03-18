import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView()
                .background(.ultraThinMaterial)

            Divider().background(Color(hex: "#3e3e42"))

            // 主内容区
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: appState.sidebarWidth)
                    .background(.ultraThinMaterial)

                VerticalResizableDivider(
                    width: $appState.sidebarWidth,
                    minWidth: 150,
                    maxWidth: 400
                )

                VStack(spacing: 0) {
                    FileTabBarView()
                    Divider().background(Color(hex: "#3e3e42"))
                    MonacoEditorView()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HorizontalResizableDivider(
                height: $appState.bottomPanelHeight,
                minHeight: 80,
                maxHeight: 400
            )

            BottomPanelView()
                .frame(height: appState.bottomPanelHeight)
                .background(.ultraThinMaterial)

            Divider().background(Color(hex: "#3e3e42"))

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
