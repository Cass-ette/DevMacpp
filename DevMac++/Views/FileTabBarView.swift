import SwiftUI

struct FileTabBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            FileTabItem(
                fileName: appState.currentFileName,
                isModified: appState.isModified
            ) {
                // 关闭文件（Plan 2 实现）
            }
            Spacer()
        }
        .background(Color(hex: "#2d2d30"))
        .frame(height: 30)
    }
}

struct FileTabItem: View {
    let fileName: String
    let isModified: Bool
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 修改标记圆点
            if isModified {
                Circle()
                    .fill(Color(hex: "#cccccc"))
                    .frame(width: 6, height: 6)
            }

            Text(fileName)
                .font(.system(size: 12))
                .foregroundColor(.white)

            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#cccccc"))
                    .frame(width: 14, height: 14)
                    .background(isHovered ? Color.white.opacity(0.15) : Color.clear)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "#1e1e1e"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "#007acc"))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
