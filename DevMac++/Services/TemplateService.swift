import Foundation
import SwiftUI

class TemplateService: ObservableObject {
    @Published var templates: [CodeTemplate] = []
    @Published var selectedTemplate: CodeTemplate?

    private let templatesURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devmacDir = appSupport.appendingPathComponent("DevMac++", isDirectory: true)
        try? FileManager.default.createDirectory(at: devmacDir, withIntermediateDirectories: true)
        templatesURL = devmacDir.appendingPathComponent("templates.json")

        loadTemplates()
    }

    func loadTemplates() {
        let defaultTemplates = [
            CodeTemplate(
                name: "空白文件",
                content: "#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    \n    return 0;\n}\n",
                description: "标准空白 C++ 文件"
            )
        ]

        guard FileManager.default.fileExists(atPath: templatesURL.path) else {
            templates = defaultTemplates
            saveTemplates()
            return
        }

        do {
            let data = try Data(contentsOf: templatesURL)
            templates = try JSONDecoder().decode([CodeTemplate].self, from: data)
        } catch {
            templates = defaultTemplates
        }
    }

    func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: templatesURL)
        } catch {
            print("Failed to save templates: \(error)")
        }
    }

    func addTemplate(name: String, content: String, description: String = "") {
        let template = CodeTemplate(name: name, content: content, description: description)
        templates.append(template)
        saveTemplates()
    }

    func removeTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }
}
