import Foundation
import SwiftUI

class TemplateService: ObservableObject {
    @Published var templates: [CodeTemplate] = []

    private let userTemplatesURL: URL

    private static let builtInTemplates: [CodeTemplate] = [
        CodeTemplate(
            name: "空白文件",
            content: "#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    \n    return 0;\n}\n",
            description: "标准空白 C++ 文件",
            isBuiltIn: true
        ),
        CodeTemplate(
            name: "竞赛模板（快速 I/O）",
            content: "#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    ios::sync_with_stdio(false);\n    cin.tie(nullptr);\n    \n    \n    return 0;\n}\n",
            description: "含快速读入的竞赛模板",
            isBuiltIn: true
        ),
        CodeTemplate(
            name: "多测试用例",
            content: "#include <bits/stdc++.h>\nusing namespace std;\n\nvoid solve() {\n    \n}\n\nint main() {\n    ios::sync_with_stdio(false);\n    cin.tie(nullptr);\n    int t;\n    cin >> t;\n    while (t--) solve();\n    return 0;\n}\n",
            description: "T 组测试用例框架",
            isBuiltIn: true
        )
    ]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devmacDir = appSupport.appendingPathComponent("DevMac++", isDirectory: true)
        try? FileManager.default.createDirectory(at: devmacDir, withIntermediateDirectories: true)
        userTemplatesURL = devmacDir.appendingPathComponent("user_templates.json")
        loadTemplates()
    }

    func loadTemplates() {
        var userTemplates: [CodeTemplate] = []
        if let data = try? Data(contentsOf: userTemplatesURL),
           let decoded = try? JSONDecoder().decode([CodeTemplate].self, from: data) {
            userTemplates = decoded
        }
        templates = Self.builtInTemplates + userTemplates
    }

    private func saveUserTemplates() {
        let userTemplates = templates.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(userTemplates) {
            try? data.write(to: userTemplatesURL)
        }
    }

    func addTemplate(name: String, content: String, description: String = "") {
        let template = CodeTemplate(name: name, content: content, description: description, isBuiltIn: false)
        templates.append(template)
        saveUserTemplates()
    }

    func removeTemplate(id: UUID) {
        guard templates.first(where: { $0.id == id })?.isBuiltIn == false else { return }
        templates.removeAll { $0.id == id }
        saveUserTemplates()
    }
}
