import Foundation
import Combine

@MainActor
final class NotesStore: ObservableObject {
	@Published var items: [NoteItem] = [] { didSet { persist() } }
	@Published var pageNotes: [Int: String] = [:] { didSet { persist() } }
	@Published var availableTags: Set<String> = []
	
	private var currentPDFURL: URL?
	private let persistenceService: NotesPersistenceProtocol
	
	init(persistenceService: NotesPersistenceProtocol? = nil) {
		self.persistenceService = persistenceService ?? NotesPersistenceService()
	}
	
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
	
	private func persist() { 
		guard let url = currentPDFURL else { return }
		persistForPDF(url)
	}
	
	private func persistForPDF(_ url: URL) {
		do {
			// Save all data atomically using transaction
			try persistenceService.saveNotes(items, for: url)
			try persistenceService.savePageNotes(pageNotes, for: url)
			try persistenceService.saveTags(availableTags, for: url)
		} catch {
			// Handle persistence errors gracefully
			print("Failed to persist notes for PDF: \(url.lastPathComponent), error: \(error)")
		}
	}
	
	private func loadForPDF(_ url: URL) {
		// Load all data
		items = persistenceService.loadNotes(for: url)
		pageNotes = persistenceService.loadPageNotes(for: url)
		availableTags = persistenceService.loadTags(for: url)
		
		// Validate data integrity
		if !persistenceService.validateData(for: url) {
			print("Data validation failed for PDF: \(url.lastPathComponent)")
			// Could implement recovery logic here
		}
	}
}
