import Foundation
import UniformTypeIdentifiers
import AppKit
import PDFKit

enum FileService {
    // OpenPanel helpers
    static func openPDF(multiple: Bool = false) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = multiple
        let result = panel.runModal()
        guard result == .OK else { return [] }
        return panel.urls
    }

    // NSSavePanel helper
    static func savePlainText(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [UTType.plainText]
        return panel.runModal() == .OK ? panel.url : nil
    }

    // Validation helpers
    static func fileExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    static func isValidPDF(_ url: URL) -> Bool {
        guard fileExists(url) else { return false }
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return false }
        return true
    }
}


