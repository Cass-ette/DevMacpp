import Foundation

struct CodeTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var description: String
    var createdAt: Date

    init(name: String, content: String, description: String = "") {
        self.id = UUID()
        self.name = name
        self.content = content
        self.description = description
        self.createdAt = Date()
    }
}
