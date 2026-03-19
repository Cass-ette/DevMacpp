import Foundation

struct CodeTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var description: String
    var createdAt: Date
    var isBuiltIn: Bool

    // isBuiltIn 不持久化，解码时始终为 false，内置模板由 TemplateService 硬编码
    enum CodingKeys: String, CodingKey {
        case id, name, content, description, createdAt
    }

    init(name: String, content: String, description: String = "", isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.description = description
        self.createdAt = Date()
        self.isBuiltIn = isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        content = try c.decode(String.self, forKey: .content)
        description = try c.decode(String.self, forKey: .description)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isBuiltIn = false
    }
}
