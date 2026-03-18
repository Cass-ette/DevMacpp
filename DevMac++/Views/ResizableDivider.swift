import SwiftUI

// 垂直分割线（左右拖拽）
struct VerticalResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(width: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = dragStartWidth + value.translation.width
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
                    .onEnded { _ in
                        dragStartWidth = width
                    }
            )
            .onAppear { dragStartWidth = width }
    }
}

// 水平分割线（上下拖拽）
struct HorizontalResizableDivider: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var dragStartHeight: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3e3e42"))
            .frame(height: 4)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = dragStartHeight - value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        dragStartHeight = height
                    }
            )
            .onAppear { dragStartHeight = height }
    }
}
