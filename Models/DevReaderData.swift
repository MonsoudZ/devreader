import Foundation

nonisolated struct DevReaderData: Codable, Sendable {
    let library: [LibraryItem]
    let recentDocuments: [String]
    let pinnedDocuments: [String]
    var webBookmarks: [String]?
    let exportDate: Date
    let version: String
}
