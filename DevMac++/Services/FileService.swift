import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FileService: ObservableObject {
    @Published var currentFilePath: String?

    func newFile(appState: AppState) {
        appState.currentFilePath = nil
        appState.currentFileName = "未保存.cpp"
        appState.fileContent = ""
        appState.isModified = false
        appState.fileSize = 0
    }

    func openFile(appState: AppState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cpp") ?? .sourceCode,
            UTType(filenameExtension: "c") ?? .sourceCode,
            UTType(filenameExtension: "h") ?? .sourceCode
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                currentFilePath = url.path
                appState.currentFilePath = url.path
                appState.currentFileName = url.lastPathComponent
                appState.fileContent = content
                appState.isModified = false
                appState.fileSize = content.utf8.count
            } catch {
                print("Failed to open file: \(error)")
            }
        }
    }

    func saveFile(appState: AppState) {
        if let path = currentFilePath {
            saveToPath(path, appState: appState)
        } else {
            saveAs(appState: appState)
        }
    }

    func saveAs(appState: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "cpp") ?? .sourceCode]
        panel.nameFieldStringValue = appState.currentFileName

        if panel.runModal() == .OK, let url = panel.url {
            saveToPath(url.path, appState: appState)
            currentFilePath = url.path
        }
    }

    private func saveToPath(_ path: String, appState: AppState) {
        do {
            try appState.fileContent.write(toFile: path, atomically: true, encoding: .utf8)
            appState.isModified = false
            let name = (path as NSString).lastPathComponent
            appState.currentFileName = name
            appState.currentFilePath = path
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}
