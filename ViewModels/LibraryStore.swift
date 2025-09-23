import Foundation
import Combine

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
		if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
	}

	private func restore() {
		guard let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) else { return }
		items = decoded
	}
}
