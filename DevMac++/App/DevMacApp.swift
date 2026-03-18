import SwiftUI

@main
struct DevMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var fileService = FileService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(fileService)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppMenuCommands()
        }
    }
}
