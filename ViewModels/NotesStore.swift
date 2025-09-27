import Foundation
import Combine

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
		if let currentURL = currentPDFURL { persistForPDF(currentURL) }
		currentPDFURL = url
		if let url = url { loadForPDF(url) } else { items = []; pageNotes = [:] }
	}
	
	func add(_ note: NoteItem) { 
		LoadingStateManager.shared.startLoading(.general, message: "Adding note...")
		items.insert(note, at: 0)
		LoadingStateManager.shared.stopLoading(.general)
	}
	
	func remove(_ note: NoteItem) { 
		LoadingStateManager.shared.startLoading(.general, message: "Removing note...")
		items.removeAll { $0.id == note.id }
		LoadingStateManager.shared.stopLoading(.general)
	}
	
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
		if let index = items.firstIndex(where: { $0.id == note.id }) { items[index].tags.removeAll { $0 == tag } }
	}
	
	func notesWithTag(_ tag: String) -> [NoteItem] { items.filter { $0.tags.contains(tag) } }
	
	private func persist() { guard let url = currentPDFURL else { return }; persistForPDF(url) }
	
	private func persistForPDF(_ url: URL) {
        let pdfKey = PersistenceService.key(notesKey, for: url)
        let pageKey = PersistenceService.key(pageNotesKey, for: url)
        let tagsKey = PersistenceService.key(self.tagsKey, for: url)
        PersistenceService.saveCodable(items, forKey: pdfKey)
        PersistenceService.saveCodable(pageNotes, forKey: pageKey)
        PersistenceService.saveCodable(Array(availableTags), forKey: tagsKey)
	}
	
	private func loadForPDF(_ url: URL) {
        let pdfKey = PersistenceService.key(notesKey, for: url)
        let pageKey = PersistenceService.key(pageNotesKey, for: url)
        let tagsKey = PersistenceService.key(self.tagsKey, for: url)
        if let decoded: [NoteItem] = PersistenceService.loadCodable([NoteItem].self, forKey: pdfKey) { items = decoded } else { items = [] }
        if let decoded: [Int: String] = PersistenceService.loadCodable([Int: String].self, forKey: pageKey) { pageNotes = decoded } else { pageNotes = [:] }
        if let decoded: [String] = PersistenceService.loadCodable([String].self, forKey: tagsKey) { availableTags = Set(decoded) } else { availableTags = [] }
	}
}
