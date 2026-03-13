import Foundation
import Combine
import os.log

@MainActor
final class NotesStore: ObservableObject {
	@Published var items: [NoteItem] = []
	@Published var pageNotes: [Int: String] = [:]
	@Published var availableTags: Set<String> = []

	/// System undo manager — set by the view layer to enable Cmd+Z for note operations.
	var undoManager: UndoManager?

	private var currentPDFURL: URL?
	private let persistenceService: NotesPersistenceProtocol
	private var persister: DebouncedPersister?
	private var isLoading = false
	/// Exposed for tests to await background loads.
	private(set) var loadingTask: Task<Void, Never>?

	init(persistenceService: NotesPersistenceProtocol? = nil) {
		self.persistenceService = persistenceService ?? NotesPersistenceService()
	}

	func setCurrentPDF(_ url: URL?) {
		// Save current PDF data before switching
		if currentPDFURL != nil {
			persister?.flush()
		}
		loadingTask?.cancel()
		currentPDFURL = url
		if let url = url {
			isLoading = true
			let service = persistenceService
			loadingTask = Task.detached(priority: .userInitiated) {
				let loadedItems = service.loadNotes(for: url)
				let loadedPageNotes = service.loadPageNotes(for: url)
				let loadedTags = service.loadTags(for: url)
				let valid = service.validateData(for: url)
				guard !Task.isCancelled else { return }
				await MainActor.run { [weak self] in
					guard let self, self.currentPDFURL == url else { return }
					self.items = loadedItems
					self.pageNotes = loadedPageNotes
					self.availableTags = loadedTags
					if !valid {
						logError(AppLog.notes, "Data validation failed for PDF: \(url.lastPathComponent)")
					}
					self.isLoading = false
				}
			}
		} else {
			items = []
			pageNotes = [:]
		}
	}

	func add(_ note: NoteItem) {
		items.insert(note, at: 0)
		registerUndo(actionName: "Add Note") { [weak self] in
			self?.remove(note)
		}
		schedulePersist()
	}

	func remove(_ note: NoteItem) {
		guard let index = items.firstIndex(where: { $0.id == note.id }) else { return }
		let removed = items.remove(at: index)
		registerUndo(actionName: "Remove Note") { [weak self] in
			self?.items.insert(removed, at: min(index, self?.items.count ?? 0))
			self?.schedulePersist()
		}
		schedulePersist()
	}

	func updateText(_ text: String, for note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			let oldText = items[index].text
			items[index].text = text
			registerUndo(actionName: "Edit Note") { [weak self] in
				self?.updateText(oldText, for: note)
			}
			schedulePersist()
		}
	}

	func updateNote(title: String, text: String, for note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			let oldTitle = items[index].title
			let oldText = items[index].text
			items[index].title = title
			items[index].text = text
			registerUndo(actionName: "Edit Note") { [weak self] in
				self?.updateNote(title: oldTitle, text: oldText, for: note)
			}
			schedulePersist()
		}
	}

	func groupedByChapter() -> [(key: String, value: [NoteItem])] {
		let groups = Dictionary(grouping: items) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
		return groups.sorted { $0.key < $1.key }
	}

	/// Move notes within a chapter group, updating the flat items array to match.
	func moveNotes(in chapter: String, from source: IndexSet, to destination: Int) {
		let chapterKey = chapter
		var chapterItems = items.filter {
			let key = $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter
			return key == chapterKey
		}
		let oldOrder = chapterItems
		// Manual move: extract items at source indices, insert at destination
		let movedItems = source.sorted(by: >).map { chapterItems.remove(at: $0) }.reversed()
		let adjustedDest = min(destination, chapterItems.count)
		chapterItems.insert(contentsOf: movedItems, at: adjustedDest)

		// Rebuild the flat items array preserving the new order within this chapter
		var result: [NoteItem] = []
		var chapterIndex = 0
		for item in items {
			let key = item.chapter.isEmpty ? "(No Chapter)" : item.chapter
			if key == chapterKey {
				result.append(chapterItems[chapterIndex])
				chapterIndex += 1
			} else {
				result.append(item)
			}
		}
		items = result
		registerUndo(actionName: "Reorder Notes") { [weak self] in
			// Restore old order
			var restored: [NoteItem] = []
			var idx = 0
			for item in result {
				let key = item.chapter.isEmpty ? "(No Chapter)" : item.chapter
				if key == chapterKey {
					restored.append(oldOrder[idx])
					idx += 1
				} else {
					restored.append(item)
				}
			}
			self?.items = restored
			self?.schedulePersist()
		}
		schedulePersist()
	}

	func note(for pageIndex: Int) -> String { pageNotes[pageIndex] ?? "" }
	func setNote(_ text: String, for pageIndex: Int) {
		pageNotes[pageIndex] = text
		schedulePersist()
	}

	func addTag(_ tag: String, to note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			guard !items[index].tags.contains(tag) else { return }
			items[index].tags.append(tag)
			availableTags.insert(tag)
			registerUndo(actionName: "Add Tag") { [weak self] in
				self?.removeTag(tag, from: note)
			}
			schedulePersist()
		}
	}

	func removeTag(_ tag: String, from note: NoteItem) {
		if let index = items.firstIndex(where: { $0.id == note.id }) {
			items[index].tags.removeAll { $0 == tag }
			registerUndo(actionName: "Remove Tag") { [weak self] in
				self?.addTag(tag, to: note)
			}
			schedulePersist()
		}
	}

	func notesWithTag(_ tag: String) -> [NoteItem] { items.filter { $0.tags.contains(tag) } }

	// MARK: - Tag Management

	/// Rename a tag across all notes.
	func renameTag(_ oldName: String, to newName: String) {
		let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty, oldName != trimmed else { return }
		for i in items.indices {
			if let tagIndex = items[i].tags.firstIndex(of: oldName) {
				items[i].tags[tagIndex] = trimmed
			}
		}
		availableTags.remove(oldName)
		availableTags.insert(trimmed)
		registerUndo(actionName: "Rename Tag") { [weak self] in
			self?.renameTag(trimmed, to: oldName)
		}
		schedulePersist()
	}

	/// Merge sourceTag into targetTag (all notes with sourceTag get targetTag instead).
	func mergeTags(_ sourceTag: String, into targetTag: String) {
		guard sourceTag != targetTag else { return }
		for i in items.indices {
			if items[i].tags.contains(sourceTag) {
				items[i].tags.removeAll { $0 == sourceTag }
				if !items[i].tags.contains(targetTag) {
					items[i].tags.append(targetTag)
				}
			}
		}
		availableTags.remove(sourceTag)
		schedulePersist()
	}

	/// Delete a tag from all notes.
	func deleteTag(_ tag: String) {
		let affectedNoteIDs = items.filter { $0.tags.contains(tag) }.map { $0.id }
		for i in items.indices {
			items[i].tags.removeAll { $0 == tag }
		}
		availableTags.remove(tag)
		registerUndo(actionName: "Delete Tag") { [weak self] in
			guard let self else { return }
			for id in affectedNoteIDs {
				if let idx = self.items.firstIndex(where: { $0.id == id }) {
					self.items[idx].tags.append(tag)
				}
			}
			self.availableTags.insert(tag)
			self.schedulePersist()
		}
		schedulePersist()
	}

	/// Immediately flush any pending debounced persistence (call on lifecycle events).
	func flushPendingPersistence() {
		persister?.flush()
	}

	// MARK: - Undo Support

	private func registerUndo(actionName: String, handler: @escaping @MainActor () -> Void) {
		guard let undoManager else { return }
		undoManager.registerUndo(withTarget: self) { _ in
			Task { @MainActor in handler() }
		}
		undoManager.setActionName(actionName)
	}

	private func schedulePersist() {
		guard !isLoading else { return }
		if persister == nil {
			persister = DebouncedPersister { [weak self] in
				guard let self, let url = self.currentPDFURL else { return }
				self.persistForPDF(url)
			}
		}
		persister?.schedule()
	}

	private func persistForPDF(_ url: URL) {
		do {
			try persistenceService.saveNotes(items, for: url)
			try persistenceService.savePageNotes(pageNotes, for: url)
			try persistenceService.saveTags(availableTags, for: url)
			SpotlightService.shared.indexNotes(items, pdfTitle: url.deletingPathExtension().lastPathComponent, pdfURL: url)
		} catch {
			logError(AppLog.notes, "Failed to persist notes for PDF: \(url.lastPathComponent), error: \(error)")
			persistenceFailurePublisher.send(
				"Failed to save notes for \(url.lastPathComponent): \(error.localizedDescription)"
			)
		}
	}

	/// Published when a write failure occurs so the UI layer can show a toast.
	let persistenceFailurePublisher = PassthroughSubject<String, Never>()

}
