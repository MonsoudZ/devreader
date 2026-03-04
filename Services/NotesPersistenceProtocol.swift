import Foundation

/// Protocol for notes persistence to enable dependency injection and testing
@MainActor
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
    private let persistenceService: EnhancedPersistenceService

    init(persistenceService: EnhancedPersistenceService = .shared) {
        self.persistenceService = persistenceService
    }
    
    private let notesKey = "DevReader.Notes.v1"
    private let pageNotesKey = "DevReader.PageNotes.v1"
    private let tagsKey = "DevReader.Tags.v1"
    
    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        try persistenceService.saveCodable(notes, forKey: notesKey, url: url)
    }
    
    func loadNotes(for url: URL) -> [NoteItem] {
        return persistenceService.loadCodableWithMigration([NoteItem].self, forKey: notesKey, url: url) ?? []
    }
    
    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws {
        try persistenceService.saveCodable(pageNotes, forKey: pageNotesKey, url: url)
    }
    
    func loadPageNotes(for url: URL) -> [Int: String] {
        return persistenceService.loadCodableWithMigration([Int: String].self, forKey: pageNotesKey, url: url) ?? [:]
    }
    
    func saveTags(_ tags: Set<String>, for url: URL) throws {
        try persistenceService.saveCodable(Array(tags), forKey: tagsKey, url: url)
    }
    
    func loadTags(for url: URL) -> Set<String> {
        return Set(persistenceService.loadCodableWithMigration([String].self, forKey: tagsKey, url: url) ?? [])
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

