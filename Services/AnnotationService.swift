import Foundation
import PDFKit

enum AnnotationService {
    private static let folderName = "Annotations"

    private static func appSupportDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("DevReader", isDirectory: true).appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func annotatedURL(for original: URL) -> URL? {
        guard let dir = appSupportDirectory() else { return nil }
        let file = String(original.path.hashValue) + ".pdf"
        return dir.appendingPathComponent(file)
    }

    static func saveAnnotatedCopy(document: PDFDocument?, originalURL: URL?) {
        guard let doc = document, let src = originalURL, let dst = annotatedURL(for: src) else { return }
        if let data = doc.dataRepresentation() { try? data.write(to: dst) }
    }
}


