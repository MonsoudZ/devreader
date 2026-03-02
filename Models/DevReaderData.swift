import Foundation

struct DevReaderData: Codable, Sendable {
    let library: [LibraryItem]
    let recentDocuments: [String]
    let pinnedDocuments: [String]
    let exportDate: Date
    let version: String
}
