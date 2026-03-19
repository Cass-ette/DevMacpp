import SwiftUI
import AppKit
import Combine

@main
struct DevMacApp: App {
    @StateObject private var setupService = SetupService()

    var body: some Scene {
        WindowGroup {
            WindowContent()
                .environmentObject(setupService)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

/// 每窗口独立的内容视图（自带服务实例）
struct WindowContent: View {
    @StateObject private var appState = AppState()
    @StateObject private var fileService = FileService()
    @StateObject private var compilerService = CompilerService()
    @StateObject private var debuggerService = DebuggerService()
    @StateObject private var runtimeService = RuntimeService()
    @StateObject private var templateService = TemplateService()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView()
                .background(.ultraThinMaterial)
                .zIndex(1)

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
        .environmentObject(appState)
        .environmentObject(fileService)
        .environmentObject(compilerService)
        .environmentObject(debuggerService)
        .environmentObject(runtimeService)
        .environmentObject(templateService)
    }
}
