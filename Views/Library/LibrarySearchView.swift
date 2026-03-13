import SwiftUI
@preconcurrency import PDFKit

/// Searches text content across all PDFs in the library.
struct LibrarySearchView: View {
	@ObservedObject var library: LibraryStore
	var onOpen: (LibraryItem, Int) -> Void
	@Environment(\.dismiss) private var dismiss

	@State private var query = ""
	@State private var results: [LibrarySearchResult] = []
	@State private var isSearching = false
	@State private var searchTask: Task<Void, Never>?
	@State private var searchProgress: (current: Int, total: Int) = (0, 0)

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Search All PDFs")
					.font(DS.Typography.heading)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(DSSecondaryButtonStyle())
					.controlSize(.small)
			}
			.padding(DS.Spacing.lg)

			HStack(spacing: DS.Spacing.sm) {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(DS.Colors.secondary)
				TextField("Search across library…", text: $query)
					.textFieldStyle(.plain)
					.onSubmit { performSearch() }
					.accessibilityIdentifier("librarySearchAllField")
					.accessibilityLabel("Search all PDFs")

				if isSearching {
					if searchProgress.total > 0 {
						Text("\(searchProgress.current)/\(searchProgress.total)")
							.font(DS.Typography.caption)
							.foregroundStyle(DS.Colors.secondary)
							.monospacedDigit()
					}
					ProgressView()
						.controlSize(.small)
				}
			}
			.searchFieldStyle()
			.padding(.horizontal, DS.Spacing.lg)
			.padding(.bottom, DS.Spacing.sm)

			Divider()

			if results.isEmpty && !isSearching && !query.isEmpty {
				VStack(spacing: DS.Spacing.sm) {
					Spacer()
					Image(systemName: "doc.text.magnifyingglass")
						.font(.system(size: DS.Layout.iconXl))
						.foregroundStyle(DS.Colors.secondary)
					Text("No results found")
						.foregroundStyle(DS.Colors.secondary)
					Spacer()
				}
			} else if results.isEmpty && query.isEmpty {
				VStack(spacing: DS.Spacing.sm) {
					Spacer()
					Image(systemName: "text.magnifyingglass")
						.font(.system(size: DS.Layout.iconXl))
						.foregroundStyle(DS.Colors.secondary)
					Text("Enter a search term to search across all PDFs")
						.foregroundStyle(DS.Colors.secondary)
						.multilineTextAlignment(.center)
					Spacer()
				}
				.padding(DS.Spacing.lg)
			} else {
				List {
					ForEach(results) { result in
						Section {
							ForEach(result.matches) { match in
								Button {
									onOpen(result.item, match.pageIndex)
									dismiss()
								} label: {
									VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
										Text("Page \(match.pageIndex + 1)")
											.font(DS.Typography.caption)
											.foregroundStyle(DS.Colors.accent)
										Text(match.contextSnippet)
											.font(DS.Typography.caption2)
											.foregroundStyle(DS.Colors.secondary)
											.lineLimit(2)
									}
								}
								.buttonStyle(.plain)
							}
						} header: {
							HStack {
								Image(systemName: "doc.fill")
									.foregroundStyle(DS.Colors.accent)
								Text(result.item.title)
									.font(DS.Typography.subheading)
								Spacer()
								Text("\(result.matches.count) match\(result.matches.count == 1 ? "" : "es")")
									.font(DS.Typography.caption)
									.foregroundStyle(DS.Colors.secondary)
							}
						}
					}
				}
			}
		}
		.frame(width: 500, height: 450)
	}

	private func performSearch() {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			results = []
			return
		}

		searchTask?.cancel()
		isSearching = true
		results = []

		let items = library.items
		let searchQuery = trimmed

		searchTask = Task {
			var allResults: [LibrarySearchResult] = []
			searchProgress = (0, items.count)

			for (idx, item) in items.enumerated() {
				guard !Task.isCancelled else { break }
				searchProgress = (idx + 1, items.count)

				let matches = await searchPDF(item: item, query: searchQuery)
				if !matches.isEmpty {
					allResults.append(LibrarySearchResult(item: item, matches: matches))
					// Show results incrementally as they're found
					results = allResults
				}
			}

			guard !Task.isCancelled else { return }
			results = allResults
			isSearching = false
			searchProgress = (0, 0)
		}
	}

	private func searchPDF(item: LibraryItem, query: String) async -> [SearchMatch] {
		// Resolve URL from bookmark if needed
		let url: URL
		if let resolved = item.resolveURLFromBookmark() {
			url = resolved
		} else {
			url = item.url
		}

		guard FileManager.default.fileExists(atPath: url.path) else { return [] }

		// PDFKit must be used on main actor
		guard let doc = PDFDocument(url: url) else { return [] }
		let selections = doc.findString(query, withOptions: [.caseInsensitive])

		var matches: [SearchMatch] = []
		var seenPages = Set<Int>()

		for selection in selections {
			guard let page = selection.pages.first else { continue }
			let pageIndex = doc.index(for: page)
			guard pageIndex >= 0, !seenPages.contains(pageIndex) else { continue }
			seenPages.insert(pageIndex)

			let snippet = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? query
			let contextSnippet = String(snippet.prefix(120))
			matches.append(SearchMatch(pageIndex: pageIndex, contextSnippet: contextSnippet))
		}

		return matches.sorted { $0.pageIndex < $1.pageIndex }
	}
}

// MARK: - Supporting Types

struct LibrarySearchResult: Identifiable {
	let id = UUID()
	let item: LibraryItem
	let matches: [SearchMatch]
}

struct SearchMatch: Identifiable {
	let id = UUID()
	let pageIndex: Int
	let contextSnippet: String
}
