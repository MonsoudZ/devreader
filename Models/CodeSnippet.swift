import Foundation

struct CodeSnippet: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var language: String
    let createdDate: Date
    var lastModified: Date

    init(id: UUID = UUID(), title: String, content: String, language: String, createdDate: Date, lastModified: Date) {
        self.id = id
        self.title = title
        self.content = content
        self.language = language
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
}
