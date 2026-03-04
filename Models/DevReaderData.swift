import Foundation

/// Per-PDF annotation bundle for export/import
nonisolated struct AnnotationBundle: Codable, Sendable {
    let hash: String
    let annotations: [PDFAnnotationData]
}

nonisolated struct DevReaderData: Codable, Sendable {
    let library: [LibraryItem]
    let recentDocuments: [String]
    let pinnedDocuments: [String]
    var webBookmarks: [String]?
    var annotationBundles: [AnnotationBundle]?
    let exportDate: Date
    let version: String
}
