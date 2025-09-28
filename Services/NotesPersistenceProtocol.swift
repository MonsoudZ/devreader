import Foundation

/// Protocol for notes persistence to enable dependency injection and testing
protocol NotesPersistenceProtocol {
    func saveNotes(_ notes: [NoteItem], for url: URL) throws
    func loadNotes(for url: URL) -> [NoteItem]
    
    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws
    func loadPageNotes(for url: URL) -> [Int: String]
    
    func saveTags(_ tags: Set<String>, for url: URL) throws
    func loadTags(for url: URL) -> Set<String>
    
    func clearData(for url: URL)
    func validateData(for url: URL) -> Bool
}

/// Production implementation using EnhancedPersistenceService
@MainActor
class NotesPersistenceService: NotesPersistenceProtocol {
    private let persistenceService = EnhancedPersistenceService.shared
    
    private let notesKey = "DevReader.Notes.v1"
    private let pageNotesKey = "DevReader.PageNotes.v1"
    private let tagsKey = "DevReader.Tags.v1"
    
    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        try persistenceService.saveCodable(notes, forKey: notesKey, url: url)
    }
    
    func loadNotes(for url: URL) -> [NoteItem] {
        return persistenceService.loadCodable([NoteItem].self, forKey: notesKey, url: url) ?? []
    }
    
    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws {
        try persistenceService.saveCodable(pageNotes, forKey: pageNotesKey, url: url)
    }
    
    func loadPageNotes(for url: URL) -> [Int: String] {
        return persistenceService.loadCodable([Int: String].self, forKey: pageNotesKey, url: url) ?? [:]
    }
    
    func saveTags(_ tags: Set<String>, for url: URL) throws {
        try persistenceService.saveCodable(Array(tags), forKey: tagsKey, url: url)
    }
    
    func loadTags(for url: URL) -> Set<String> {
        return Set(persistenceService.loadCodable([String].self, forKey: tagsKey, url: url) ?? [])
    }
    
    func clearData(for url: URL) {
        persistenceService.clearData(for: url)
    }
    
    func validateData(for url: URL) -> Bool {
        return persistenceService.validateData(forKey: notesKey, url: url) &&
               persistenceService.validateData(forKey: pageNotesKey, url: url) &&
               persistenceService.validateData(forKey: tagsKey, url: url)
    }
}

/// Mock implementation for testing
class MockNotesPersistenceService: NotesPersistenceProtocol {
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
