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
		if let index = items.firstIndex(where: { $0.id == note.id }) { items[index].tags.removeAll { $0 == tag } }
	}
	
	func notesWithTag(_ tag: String) -> [NoteItem] { items.filter { $0.tags.contains(tag) } }
	
	private func persist() { guard let url = currentPDFURL else { return }; persistForPDF(url) }
	
	private func persistForPDF(_ url: URL) {
		let pdfKey = "\(notesKey).\(url.path.hashValue)"
		let pageKey = "\(pageNotesKey).\(url.path.hashValue)"
		let tagsKey = "\(self.tagsKey).\(url.path.hashValue)"
		if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: pdfKey) }
		if let data = try? JSONEncoder().encode(pageNotes) { UserDefaults.standard.set(data, forKey: pageKey) }
		if let data = try? JSONEncoder().encode(Array(availableTags)) { UserDefaults.standard.set(data, forKey: tagsKey) }
	}
	
	private func loadForPDF(_ url: URL) {
		let pdfKey = "\(notesKey).\(url.path.hashValue)"
		let pageKey = "\(pageNotesKey).\(url.path.hashValue)"
		let tagsKey = "\(self.tagsKey).\(url.path.hashValue)"
		if let data = UserDefaults.standard.data(forKey: pdfKey), let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) { items = decoded } else { items = [] }
		if let data = UserDefaults.standard.data(forKey: pageKey), let decoded = try? JSONDecoder().decode([Int: String].self, from: data) { pageNotes = decoded } else { pageNotes = [:] }
		if let data = UserDefaults.standard.data(forKey: tagsKey), let decoded = try? JSONDecoder().decode([String].self, from: data) { availableTags = Set(decoded) } else { availableTags = [] }
	}
}
