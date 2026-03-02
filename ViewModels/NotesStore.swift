import Foundation
import Combine
import os.log

@MainActor
final class NotesStore: ObservableObject {
	@Published var items: [NoteItem] = []
	@Published var pageNotes: [Int: String] = [:]
	@Published var availableTags: Set<String> = []

	private var currentPDFURL: URL?
	private let persistenceService: NotesPersistenceProtocol
	private var persistWorkItem: DispatchWorkItem?
	private var isLoading = false

	init(persistenceService: NotesPersistenceProtocol? = nil) {
		self.persistenceService = persistenceService ?? NotesPersistenceService()
	}

	func setCurrentPDF(_ url: URL?) {
		// Save current PDF data before switching
		if let currentURL = currentPDFURL {
			persistWorkItem?.cancel()
			persistForPDF(currentURL)
		}
		currentPDFURL = url
		if let url = url {
			isLoading = true
			loadForPDF(url)
			isLoading = false
		} else {
			items = []
			pageNotes = [:]
		}
	}

	func add(_ note: NoteItem) {
		LoadingStateManager.shared.startLoading(.general, message: "Adding note...")
		items.insert(note, at: 0)
		schedulePersist()
		LoadingStateManager.shared.stopLoading(.general)
	}

	func remove(_ note: NoteItem) {
		LoadingStateManager.shared.startLoading(.general, message: "Removing note...")
		items.removeAll { $0.id == note.id }
		schedulePersist()
		LoadingStateManager.shared.stopLoading(.general)
	}

	func updateText(_ text: String, for note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			items[index].text = text
			schedulePersist()
		}
	}

	func groupedByChapter() -> [(key: String, value: [NoteItem])] {
		let groups = Dictionary(grouping: items) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
		return groups.sorted { $0.key < $1.key }
	}

	func note(for pageIndex: Int) -> String { pageNotes[pageIndex] ?? "" }
	func setNote(_ text: String, for pageIndex: Int) {
		pageNotes[pageIndex] = text
		schedulePersist()
	}

	func addTag(_ tag: String, to note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			items[index].tags.append(tag)
			availableTags.insert(tag)
			schedulePersist()
		}
	}

	func removeTag(_ tag: String, from note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			items[index].tags.removeAll { $0 == tag }
			schedulePersist()
		}
	}

	func notesWithTag(_ tag: String) -> [NoteItem] { items.filter { $0.tags.contains(tag) } }

	private func schedulePersist() {
		guard !isLoading else { return }
		persistWorkItem?.cancel()
		let workItem = DispatchWorkItem { [weak self] in
			Task { @MainActor in
				guard let self = self, let url = self.currentPDFURL else { return }
				self.persistForPDF(url)
			}
		}
		persistWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
	}

	private func persistForPDF(_ url: URL) {
		do {
			try persistenceService.saveNotes(items, for: url)
			try persistenceService.savePageNotes(pageNotes, for: url)
			try persistenceService.saveTags(availableTags, for: url)
		} catch {
			logError(AppLog.notes, "Failed to persist notes for PDF: \(url.lastPathComponent), error: \(error)")
		}
	}

	private func loadForPDF(_ url: URL) {
		items = persistenceService.loadNotes(for: url)
		pageNotes = persistenceService.loadPageNotes(for: url)
		availableTags = persistenceService.loadTags(for: url)

		if !persistenceService.validateData(for: url) {
			logError(AppLog.notes, "Data validation failed for PDF: \(url.lastPathComponent)")
		}
	}
}
