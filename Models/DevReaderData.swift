import Foundation

/// Per-PDF annotation bundle for export/import
nonisolated struct AnnotationBundle: Codable, Sendable {
    let hash: String
    let annotations: [PDFAnnotationData]
}

/// Per-PDF notes bundle for export/import
nonisolated struct NotesBundle: Codable, Sendable {
    let hash: String
    let notes: [NoteItem]
    var pageNotes: [Int: String]?
    var tags: [String]?
}

/// Per-PDF bookmarks bundle for export/import
nonisolated struct BookmarksBundle: Codable, Sendable {
    let hash: String
    let bookmarks: [Int]
}

/// Per-PDF session bundle for export/import
nonisolated struct SessionBundle: Codable, Sendable {
    let hash: String
    let data: Data
}

nonisolated struct DevReaderData: Codable, Sendable {
    let library: [LibraryItem]
    let recentDocuments: [String]
    let pinnedDocuments: [String]
    var webBookmarks: [String]?
    var annotationBundles: [AnnotationBundle]?
    var notesBundles: [NotesBundle]?
    var bookmarksBundles: [BookmarksBundle]?
    var sessionBundles: [SessionBundle]?
    var sketches: [SketchItem]?
    let exportDate: Date
    let version: String
}
