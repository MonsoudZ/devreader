import Foundation

struct WebBookmark: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var url: String
    let createdDate: Date

    init(id: UUID = UUID(), title: String, url: String, createdDate: Date) {
        self.id = id
        self.title = title
        self.url = url
        self.createdDate = createdDate
    }
}
