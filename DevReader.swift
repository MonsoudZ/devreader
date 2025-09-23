// DevReader.swift
// One-file macOS SwiftUI app: PDF library + reader with notes, quick highlight capture,
// chapter-aware organization, code scratchpad/Monaco, sketch page insert, side WKWebView.
// Targets: macOS 13+

import SwiftUI
import PDFKit
import WebKit
import Combine
import AppKit
import UniformTypeIdentifiers

// Import extracted models
// Note: In a real project, you would use proper module imports
// For now, we'll keep the models in the same target

// MARK: - App
// App moved to App/DevReaderApp.swift and App/ContentView.swift

// MARK: - Models
// Models have been moved to separate files in the Models/ directory

#if false // moved to ViewModels/PDFController.swift
@MainActor
final class PDFController: ObservableObject {
    @Published var document: PDFDocument?
    @Published var currentPageIndex: Int = 0 { didSet { persist() } }
    @Published var outlineMap: [Int: String] = [:] // pageIndex -> chapter title
    @Published var bookmarks: Set<Int> = [] // pageIndex -> bookmarked
    
    private let sessionKey = "DevReader.Session.v1"
    private let bookmarksKey = "DevReader.Bookmarks.v1"
    private var currentPDFURL: URL?
    private let annotationFolderName = "Annotations"
    
    init() { restore() }
    
    func load(url: URL) {
        // Save current PDF's page before switching
        if let currentURL = currentPDFURL {
            savePageForPDF(currentURL)
        }
        
        // Try to load annotated version first, fallback to original
        let sourceURL: URL = {
            if let annotated = self.annotatedURL(for: url), FileManager.default.fileExists(atPath: annotated.path) {
                return annotated
            }
            return url
        }()
        
        if let doc = PDFDocument(url: sourceURL) {
            self.document = doc
            self.currentPDFURL = url
            rebuildOutlineMap()
            loadPageForPDF(url)
            loadBookmarks()
            onPDFChanged?(url)
        } else {
            // Error handling will be done by the calling view
        }
    }
    
    func clearSession() {
        // Save current PDF's page before clearing
        if let currentURL = currentPDFURL {
            savePageForPDF(currentURL)
        }
        
        document = nil
        currentPDFURL = nil
        currentPageIndex = 0
        outlineMap.removeAll()
        bookmarks.removeAll()
        UserDefaults.standard.removeObject(forKey: sessionKey)
        onPDFChanged?(nil)
    }
    
    // Callback for notes store
    var onPDFChanged: ((URL?) -> Void)?
    
    func goToPage(_ pageIndex: Int) {
        guard let doc = document, pageIndex >= 0, pageIndex < doc.pageCount else { return }
        currentPageIndex = pageIndex
        if let url = currentPDFURL {
            savePageForPDF(url)
        }
    }
    
    func toggleBookmark(_ pageIndex: Int) {
        if bookmarks.contains(pageIndex) {
            bookmarks.remove(pageIndex)
        } else {
            bookmarks.insert(pageIndex)
        }
        saveBookmarks()
    }
    
    func isBookmarked(_ pageIndex: Int) -> Bool {
        return bookmarks.contains(pageIndex)
    }
    
    private func saveBookmarks() {
        guard let url = currentPDFURL else { return }
        let key = "\(bookmarksKey).\(url.path.hashValue)"
        let bookmarksArray = Array(bookmarks)
        UserDefaults.standard.set(bookmarksArray, forKey: key)
    }
    
    private func loadBookmarks() {
        guard let url = currentPDFURL else { return }
        let key = "\(bookmarksKey).\(url.path.hashValue)"
        if let bookmarksArray = UserDefaults.standard.array(forKey: key) as? [Int] {
            bookmarks = Set(bookmarksArray)
        }
    }

    func rebuildOutlineMap() {
        outlineMap.removeAll()
        guard let doc = document else { return }
        if let root = doc.outlineRoot {
            func walk(_ node: PDFOutline, path: [String]) {
                let title = node.label ?? "Untitled"
                let newPath = path + [title]
                if let dest = node.destination, let page = dest.page {
                    let idx = doc.index(for: page) // Int (not optional)
                    outlineMap[idx] = newPath.joined(separator: " › ")
                }
                for i in 0..<node.numberOfChildren {
                    if let child = node.child(at: i) { walk(child, path: newPath) }
                }
            }
            for i in 0..<root.numberOfChildren {
                if let c = root.child(at: i) { walk(c, path: []) }
            }
        }
    }
    
    private func persist() {
        guard let url = currentPDFURL else { return }
        savePageForPDF(url)
    }
    
    func savePageForPDF(_ url: URL) {
        let pageKey = "\(sessionKey).\(url.path.hashValue)"
        UserDefaults.standard.set(currentPageIndex, forKey: pageKey)
    }
    
    private func loadPageForPDF(_ url: URL) {
        let pageKey = "\(sessionKey).\(url.path.hashValue)"
        let savedPage = UserDefaults.standard.integer(forKey: pageKey)
        if savedPage > 0 {
            let lastIndex = max(0, (document?.pageCount ?? 1) - 1)
            currentPageIndex = min(savedPage, lastIndex)
        } else {
            currentPageIndex = 0
        }
    }
    
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(SessionData.self, from: data),
              let url = session.documentURL else { return }
        
        // Check if file still exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else { 
            // Clear invalid session
            UserDefaults.standard.removeObject(forKey: sessionKey)
            return 
        }
        
        // Try to restore the document and page
        let sourceURL: URL = {
            if let annotated = self.annotatedURL(for: url), FileManager.default.fileExists(atPath: annotated.path) {
                return annotated
            }
            return url
        }()
        
        // Only restore if we can successfully load the PDF
        if let doc = PDFDocument(url: sourceURL), doc.pageCount > 0 {
            self.document = doc
            self.currentPDFURL = url
            rebuildOutlineMap()
            loadPageForPDF(url)
            loadBookmarks()
            onPDFChanged?(url)
        } else {
            // Clear invalid session if PDF can't be loaded
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }
    
    // MARK: - Annotation persistence
    private func appSupportDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("DevReader", isDirectory: true).appendingPathComponent(annotationFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    func annotatedURL(for original: URL) -> URL? {
        guard let dir = appSupportDirectory() else { return nil }
        let file = String(original.path.hashValue) + ".pdf"
        return dir.appendingPathComponent(file)
    }
    
    func saveAnnotatedCopy() {
        guard let doc = document, let original = currentPDFURL, let dst = annotatedURL(for: original) else { return }
        if let data = doc.dataRepresentation() {
            try? data.write(to: dst)
        }
    }
    
    func clearInvalidSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        document = nil
        currentPDFURL = nil
        currentPageIndex = 0
        outlineMap.removeAll()
    }
}
#endif // moved PDFController

// SessionData has been moved to Models/SessionData.swift

#if false // moved to ViewModels/NotesStore.swift
@MainActor
final class NotesStore: ObservableObject {
    @Published var items: [NoteItem] = [] { didSet { persist() } }
    @Published var pageNotes: [Int: String] = [:] { didSet { persist() } }
    @Published var availableTags: Set<String> = []
    
    private var currentPDFURL: URL?
    private let notesKey = "DevReader.Notes.v1"
    private let pageNotesKey = "DevReader.PageNotes.v1"
    private let tagsKey = "DevReader.Tags.v1"
    
    init() { }
    
    func setCurrentPDF(_ url: URL?) {
        // Save current PDF's notes before switching
        if let currentURL = currentPDFURL {
            persistForPDF(currentURL)
        }
        
        // Load notes for new PDF
        currentPDFURL = url
        if let url = url {
            loadForPDF(url)
        } else {
            items = []
            pageNotes = [:]
        }
    }
    
    func add(_ note: NoteItem) { items.insert(note, at: 0) }

    func groupedByChapter() -> [(key: String, value: [NoteItem])] {
        let groups = Dictionary(grouping: items) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
        return groups.sorted { $0.key < $1.key }
    }

    func note(for pageIndex: Int) -> String { pageNotes[pageIndex] ?? "" }
    func setNote(_ text: String, for pageIndex: Int) { pageNotes[pageIndex] = text }
    
    func addTag(_ tag: String, to note: NoteItem) {
        if let index = items.firstIndex(where: { $0.id == note.id }) {
            items[index].tags.append(tag)
            availableTags.insert(tag)
        }
    }
    
    func removeTag(_ tag: String, from note: NoteItem) {
        if let index = items.firstIndex(where: { $0.id == note.id }) {
            items[index].tags.removeAll { $0 == tag }
        }
    }
    
    func notesWithTag(_ tag: String) -> [NoteItem] {
        return items.filter { $0.tags.contains(tag) }
    }
    
    private func persist() {
        guard let url = currentPDFURL else { return }
        persistForPDF(url)
    }
    
    private func persistForPDF(_ url: URL) {
        let pdfKey = "\(notesKey).\(url.path.hashValue)"
        let pageKey = "\(pageNotesKey).\(url.path.hashValue)"
        let tagsKey = "\(self.tagsKey).\(url.path.hashValue)"
        
        // Save notes for this PDF
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: pdfKey)
        }
        // Save page notes for this PDF
        if let data = try? JSONEncoder().encode(pageNotes) {
            UserDefaults.standard.set(data, forKey: pageKey)
        }
        // Save tags for this PDF
        if let data = try? JSONEncoder().encode(Array(availableTags)) {
            UserDefaults.standard.set(data, forKey: tagsKey)
        }
    }
    
    private func loadForPDF(_ url: URL) {
        let pdfKey = "\(notesKey).\(url.path.hashValue)"
        let pageKey = "\(pageNotesKey).\(url.path.hashValue)"
        let tagsKey = "\(self.tagsKey).\(url.path.hashValue)"
        
        // Load notes for this PDF
        if let data = UserDefaults.standard.data(forKey: pdfKey),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
        
        // Load page notes for this PDF
        if let data = UserDefaults.standard.data(forKey: pageKey),
           let decoded = try? JSONDecoder().decode([Int: String].self, from: data) {
            pageNotes = decoded
        } else {
            pageNotes = [:]
        }
        
        // Load tags for this PDF
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            availableTags = Set(decoded)
        } else {
            availableTags = []
        }
    }
}
#endif // moved NotesStore

// MARK: - Library
// LibraryItem has been moved to Models/LibraryItem.swift

#if false // moved to ViewModels/LibraryStore.swift
@MainActor
final class LibraryStore: ObservableObject {
    @Published var items: [LibraryItem] = [] { didSet { persist() } }
    private let key = "DevReader.Library.v1"

    init() { restore() }

    func add(urls: [URL]) {
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        let newItems = pdfs.map(LibraryItem.init(url:))
        let existing = Set(items.map { $0.url })
        let merged = items + newItems.filter { !existing.contains($0.url) }
        items = merged.sorted { $0.addedAt > $1.addedAt }
    }

    func remove(_ item: LibraryItem) { items.removeAll { $0.id == item.id } }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) else { return }
        items = decoded
    }
}
#endif // moved LibraryStore

// Main app views moved to App/ContentView.swift

// RightTab moved to App/ContentView.swift

// LibrarySheet moved to Views/Library if needed

// MARK: - Library Pane
// Library views moved to Views/Library

// PDF views moved to Views/PDF

// Notes views moved to Views/Notes

// Code views moved to Views/Code

// MARK: - Web Pane
// Web views moved to Views/Web

// PDF bridge and representable moved to Views/PDF

// PDFSelection extension moved to Utils

// MARK: - Sketch Window (very simple pen tool)
// Sketch window and view moved to Views/Sketch

// Path extension moved to Utils/Extensions

// Notifications moved to Utils
// Onboarding/Settings/Shell moved to Views/Onboarding, Views/Settings, Utils/Shell
