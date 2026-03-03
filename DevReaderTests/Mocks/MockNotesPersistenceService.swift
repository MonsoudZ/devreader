import Foundation
@testable import DevReader

@MainActor
final class MockNotesPersistenceService: NotesPersistenceProtocol {
    var notes: [URL: [NoteItem]] = [:]
    var pageNotes: [URL: [Int: String]] = [:]
    var tags: [URL: Set<String>] = [:]

    var shouldThrowError = false
    var lastSavedNotes: [NoteItem] = []
    var lastSavedPageNotes: [Int: String] = [:]
    var lastSavedTags: Set<String> = []

    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.notes[url] = notes
        lastSavedNotes = notes
    }

    func loadNotes(for url: URL) -> [NoteItem] {
        return notes[url] ?? []
    }

    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.pageNotes[url] = pageNotes
        lastSavedPageNotes = pageNotes
    }

    func loadPageNotes(for url: URL) -> [Int: String] {
        return pageNotes[url] ?? [:]
    }

    func saveTags(_ tags: Set<String>, for url: URL) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.tags[url] = tags
        lastSavedTags = tags
    }

    func loadTags(for url: URL) -> Set<String> {
        return tags[url] ?? []
    }

    func clearData(for url: URL) {
        notes.removeValue(forKey: url)
        pageNotes.removeValue(forKey: url)
        tags.removeValue(forKey: url)
    }

    func validateData(for url: URL) -> Bool {
        return notes[url] != nil || pageNotes[url] != nil || tags[url] != nil
    }
}
