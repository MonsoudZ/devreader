import Foundation

/// Filter configuration for notes export.
nonisolated struct ExportFilter: Codable, Equatable, Sendable {
	let selectedTag: String?
	let filterBookmarks: Bool
	let useDateFilter: Bool
	let dateFrom: Date
	let dateTo: Date
}

/// Preset for saving/loading export filter configurations.
nonisolated struct ExportPreset: Codable, Equatable, Sendable {
	let name: String
	let tag: String?
	let bookmarks: Bool
	let useDate: Bool
	let from: Date
	let to: Date
}

/// Handles Markdown export of notes with filtering, progress reporting, and preset management.
enum NotesExportService {
	/// Progress callback: (fraction 0–1, status message)
	typealias ProgressCallback = @MainActor (Double, String) -> Void

	/// Generates filtered Markdown and writes it to `saveURL`.
	/// Returns true on success, false on failure.
	static func exportMarkdown(
		to saveURL: URL,
		pageNotes: [Int: String],
		items: [NoteItem],
		bookmarks: Set<Int>,
		filter: ExportFilter,
		onProgress: ProgressCallback? = nil
	) async -> Bool {
		// Move heavy processing off main thread
		let result: Bool = await Task.detached(priority: .userInitiated) { @Sendable () -> Bool in
			let df = DateFormatter()
			df.dateStyle = .short
			df.timeStyle = .short

			var md = "# Notes Export\n\n"

			await onProgress?(0.1, "Processing page notes...")

			md += "## Page Notes\n\n"
			let pages = pageNotes.keys.sorted()
			let allowedPages: Set<Int>? = filter.filterBookmarks ? bookmarks : nil

			for (index, p) in pages.enumerated() {
				let text = pageNotes[p]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
				let include = allowedPages.map { $0.contains(p) } ?? true
				if include, !text.isEmpty {
					md += "### Page \(p + 1)\n\n\(text)\n\n"
				}
				if !pages.isEmpty {
					await onProgress?(0.1 + (0.3 * Double(index) / Double(pages.count)), "Processing page notes...")
				}
			}

			await onProgress?(0.4, "Processing notes...")

			// Filter notes
			let filteredItems = items.filter { item in
				let tagOk = filter.selectedTag.map { item.tags.contains($0) } ?? true
				let dateOk = !filter.useDateFilter || (
					item.date >= Calendar.current.startOfDay(for: filter.dateFrom)
					&& item.date <= (Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: filter.dateTo)) ?? filter.dateTo)
				)
				let bmOk = allowedPages.map { $0.contains(item.pageIndex) } ?? true
				return tagOk && dateOk && bmOk
			}

			await onProgress?(0.6, "Grouping notes by chapter...")

			let grouped = Dictionary(grouping: filteredItems) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
				.sorted { $0.key < $1.key }

			for (index, g) in grouped.enumerated() {
				md += "## \(g.key)\n\n"
				for n in g.value {
					md += "- p.\(n.pageIndex + 1) (\(df.string(from: n.date))): \(n.text)\n"
				}
				md += "\n"
				if !grouped.isEmpty {
					await onProgress?(0.6 + (0.3 * Double(index) / Double(grouped.count)), "Grouping notes by chapter...")
				}
			}

			await onProgress?(0.9, "Saving file...")

			do {
				guard let data = md.data(using: .utf8) else { return false }
				try data.write(to: saveURL)
			} catch {
				await onProgress?(0.0, "Export failed.")
				return false
			}

			return true
		}.value

		return result
	}

	// MARK: - Preset Management

	private static let presetsKey = "notes.exportPresets"

	static func loadPresets(from raw: String) -> [ExportPreset] {
		(try? JSONDecoder().decode([ExportPreset].self, from: Data(raw.utf8))) ?? []
	}

	static func encodePresets(_ presets: [ExportPreset]) -> String {
		guard let data = try? JSONEncoder().encode(presets),
			  let s = String(data: data, encoding: .utf8)
		else { return "[]" }
		return s
	}

	static func savePreset(name: String, filter: ExportFilter, existing raw: String) -> String {
		guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return raw }
		var presets = loadPresets(from: raw).filter { $0.name != name }
		presets.append(ExportPreset(
			name: name,
			tag: filter.selectedTag,
			bookmarks: filter.filterBookmarks,
			useDate: filter.useDateFilter,
			from: filter.dateFrom,
			to: filter.dateTo
		))
		return encodePresets(presets)
	}

	static func deletePreset(named: String, existing raw: String) -> String {
		encodePresets(loadPresets(from: raw).filter { $0.name != named })
	}
}
