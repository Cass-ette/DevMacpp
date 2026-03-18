import SwiftUI

@main
struct DevMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var fileService = FileService()
    @StateObject private var setupService = SetupService()
    @StateObject private var compilerService = CompilerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(fileService)
                .environmentObject(setupService)
                .environmentObject(compilerService)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppMenuCommands()
        }
    }
}
