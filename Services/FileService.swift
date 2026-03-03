import Foundation
import UniformTypeIdentifiers
import AppKit
import PDFKit

enum FileService {
    // OpenPanel helpers
    @MainActor
    static func openPDF(multiple: Bool = false) async -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = multiple
        return await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.urls : [])
            }
        }
    }

    // NSSavePanel helper
    @MainActor
    static func savePlainText(defaultName: String) async -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [UTType.plainText]
        return await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    // Validation helpers
    static func fileExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    static func isValidPDF(_ url: URL) -> Bool {
        guard fileExists(url) else { return false }
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return false }
        return true
    }
}


