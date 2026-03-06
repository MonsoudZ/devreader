import CoreSpotlight
import Foundation
import os.log

/// Indexes DevReader library items and notes for macOS Spotlight search.
@MainActor
final class SpotlightService {
	static let shared = SpotlightService()

	private let index = CSSearchableIndex.default()
	private let domainPDF = "com.monsoud.devreader.pdf"
	private let domainNote = "com.monsoud.devreader.note"

	// MARK: - PDF Library Indexing

	/// Index a batch of library items for Spotlight.
	func indexLibraryItems(_ items: [LibraryItem]) {
		let searchableItems = items.compactMap { makeSearchableItem(for: $0) }
		guard !searchableItems.isEmpty else { return }
		index.indexSearchableItems(searchableItems) { error in
			if let error {
				logError(AppLog.app, "Spotlight index error: \(error.localizedDescription)")
			}
		}
	}

	/// Index a single library item.
	func indexLibraryItem(_ item: LibraryItem) {
		guard let searchable = makeSearchableItem(for: item) else { return }
		index.indexSearchableItems([searchable]) { error in
			if let error {
				logError(AppLog.app, "Spotlight index error: \(error.localizedDescription)")
			}
		}
	}

	/// Remove a library item from the Spotlight index.
	func deindexLibraryItem(_ item: LibraryItem) {
		index.deleteSearchableItems(withIdentifiers: [pdfIdentifier(item)]) { error in
			if let error {
				logError(AppLog.app, "Spotlight deindex error: \(error.localizedDescription)")
			}
		}
	}

	/// Remove multiple library items from the Spotlight index.
	func deindexLibraryItems(_ ids: Set<UUID>) {
		let identifiers = ids.map { "\(domainPDF).\($0.uuidString)" }
		index.deleteSearchableItems(withIdentifiers: identifiers) { error in
			if let error {
				logError(AppLog.app, "Spotlight deindex error: \(error.localizedDescription)")
			}
		}
	}

	// MARK: - Notes Indexing

	/// Index notes for a specific PDF.
	func indexNotes(_ notes: [NoteItem], pdfTitle: String, pdfURL: URL?) {
		let searchableItems = notes.compactMap { makeSearchableItem(for: $0, pdfTitle: pdfTitle, pdfURL: pdfURL) }
		guard !searchableItems.isEmpty else { return }
		index.indexSearchableItems(searchableItems) { error in
			if let error {
				logError(AppLog.app, "Spotlight note index error: \(error.localizedDescription)")
			}
		}
	}

	/// Remove all notes for a PDF from the index.
	func deindexNotes(for pdfURL: URL) {
		// Delete all items in the note domain that match this PDF
		// We use the domain identifier group approach
		index.deleteSearchableItems(withDomainIdentifiers: [noteDomainForPDF(pdfURL)]) { error in
			if let error {
				logError(AppLog.app, "Spotlight note deindex error: \(error.localizedDescription)")
			}
		}
	}

	// MARK: - Full Reindex

	/// Rebuilds the entire Spotlight index from current library and notes.
	func reindexAll(library: [LibraryItem], notesStore: NotesStore) {
		// Clear everything first
		index.deleteAllSearchableItems { [weak self] error in
			guard let self else { return }
			if let error {
				logError(AppLog.app, "Spotlight clear error: \(error.localizedDescription)")
				return
			}
			Task { @MainActor in
				self.indexLibraryItems(library)
			}
		}
	}

	// MARK: - Identifier Helpers

	/// Parses a Spotlight unique identifier back to a library item UUID.
	static func libraryItemID(from uniqueIdentifier: String) -> UUID? {
		guard uniqueIdentifier.hasPrefix("com.monsoud.devreader.pdf.") else { return nil }
		let uuidString = String(uniqueIdentifier.dropFirst("com.monsoud.devreader.pdf.".count))
		return UUID(uuidString: uuidString)
	}

	/// Parses a Spotlight unique identifier to extract a note ID.
	static func noteID(from uniqueIdentifier: String) -> UUID? {
		// Format: com.monsoud.devreader.note.<hash>.<noteUUID>
		let parts = uniqueIdentifier.components(separatedBy: ".")
		guard parts.count >= 5, parts[3] == "note",
			  let uuid = UUID(uuidString: parts.last ?? "") else { return nil }
		return uuid
	}

	// MARK: - Private

	private func pdfIdentifier(_ item: LibraryItem) -> String {
		"\(domainPDF).\(item.id.uuidString)"
	}

	private func noteIdentifier(_ note: NoteItem, pdfURL: URL?) -> String {
		let pdfHash = pdfURL?.lastPathComponent.hashValue ?? 0
		return "\(domainNote).\(pdfHash).\(note.id.uuidString)"
	}

	private func noteDomainForPDF(_ url: URL) -> String {
		"\(domainNote).\(url.lastPathComponent.hashValue)"
	}

	private func makeSearchableItem(for item: LibraryItem) -> CSSearchableItem? {
		let attributes = CSSearchableItemAttributeSet(contentType: .pdf)
		attributes.title = item.title
		attributes.displayName = item.title
		attributes.contentDescription = "PDF document in DevReader library"
		attributes.path = item.url.path
		if let author = item.author {
			attributes.authorNames = [author]
		}
		attributes.pageCount = item.pageCount as NSNumber
		attributes.contentURL = item.url
		attributes.addedDate = item.addedDate

		return CSSearchableItem(
			uniqueIdentifier: pdfIdentifier(item),
			domainIdentifier: domainPDF,
			attributeSet: attributes
		)
	}

	private func makeSearchableItem(for note: NoteItem, pdfTitle: String, pdfURL: URL?) -> CSSearchableItem? {
		guard !note.text.isEmpty else { return nil }

		let attributes = CSSearchableItemAttributeSet(contentType: .text)
		attributes.title = note.displayTitle
		attributes.displayName = "\(note.displayTitle) – \(pdfTitle)"
		attributes.contentDescription = note.text
		attributes.keywords = note.tags
		attributes.creator = "DevReader"
		if let url = pdfURL {
			attributes.relatedUniqueIdentifier = "\(domainPDF).\(url.lastPathComponent)"
		}

		return CSSearchableItem(
			uniqueIdentifier: noteIdentifier(note, pdfURL: pdfURL),
			domainIdentifier: pdfURL.map { noteDomainForPDF($0) } ?? domainNote,
			attributeSet: attributes
		)
	}
}
