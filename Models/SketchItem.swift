import Foundation

nonisolated struct SketchItem: Identifiable, Codable, Sendable {
    let id: UUID
    let pdfURL: URL
    let pageIndex: Int
    var title: String
    let createdDate: Date
    var lastModified: Date
    var canvasData: Data
    var strokesData: Data?
    var isExported: Bool

    init(id: UUID = UUID(), pdfURL: URL, pageIndex: Int, title: String, createdDate: Date, lastModified: Date, canvasData: Data, strokesData: Data? = nil, isExported: Bool = false) {
        self.id = id
        self.pdfURL = pdfURL
        self.pageIndex = pageIndex
        self.title = title
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.canvasData = canvasData
        self.strokesData = strokesData
        self.isExported = isExported
    }
}
