import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 第一行：文件操作 + 编辑操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "doc", tooltip: "新建 (Cmd+N)") {}
                ToolbarButton(icon: "folder", tooltip: "打开 (Cmd+O)") {}
                ToolbarButton(icon: "square.and.arrow.down", tooltip: "保存 (Cmd+S)") {}
                ToolbarButton(icon: "square.and.arrow.down.on.square", tooltip: "另存为 (Cmd+Shift+S)") {}
                ToolbarButton(icon: "xmark", tooltip: "关闭 (Cmd+W)") {}

                ToolbarDivider()

                ToolbarButton(icon: "printer", tooltip: "打印") {}

                ToolbarDivider()

                ToolbarButton(icon: "scissors", tooltip: "剪切 (Cmd+X)") {}
                ToolbarButton(icon: "doc.on.doc", tooltip: "复制 (Cmd+C)") {}
                ToolbarButton(icon: "doc.on.clipboard", tooltip: "粘贴 (Cmd+V)") {}

                ToolbarDivider()

                ToolbarButton(icon: "arrow.uturn.backward", tooltip: "撤销 (Cmd+Z)") {}
                ToolbarButton(icon: "arrow.uturn.forward", tooltip: "重做 (Cmd+Shift+Z)") {}

                ToolbarDivider()

                ToolbarButton(icon: "magnifyingglass", tooltip: "查找 (Cmd+F)") {}
                ToolbarButton(icon: "arrow.left.arrow.right", tooltip: "替换 (Cmd+H)") {}

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider()
                .background(Color(hex: "#3e3e42"))

            // 第二行：编译 + 调试操作
            HStack(spacing: 2) {
                ToolbarButton(icon: "hammer", tooltip: "编译 (Cmd+F11)") {}
                ToolbarButton(icon: "play", tooltip: "运行 (Cmd+F10)", tint: Color(hex: "#4caf50")) {}
                ToolbarButton(icon: "play.fill", tooltip: "编译运行 (Cmd+F9)", tint: Color(hex: "#ff9800")) {}
                ToolbarButton(icon: "arrow.clockwise", tooltip: "重新编译") {}
                ToolbarButton(icon: "trash", tooltip: "清理") {}

                ToolbarDivider()

                ToolbarButton(icon: "ant", tooltip: "调试 (Cmd+F8)", tint: Color(hex: "#2196f3")) {}
                ToolbarButton(icon: "pause", tooltip: "暂停") {}
                ToolbarButton(icon: "stop", tooltip: "停止 (Cmd+F2)") {}
                ToolbarButton(icon: "arrow.down.to.line", tooltip: "单步进入 (Cmd+F11)") {}
                ToolbarButton(icon: "arrow.right.to.line", tooltip: "单步跳过 (Cmd+F10)") {}
                ToolbarButton(icon: "arrow.up.to.line", tooltip: "单步跳出 (Cmd+Shift+F11)") {}

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var tint: Color = Color(hex: "#cccccc")
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
    }
}
