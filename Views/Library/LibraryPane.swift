import SwiftUI
import PDFKit
import QuickLook
import UniformTypeIdentifiers

struct LibraryPane: View {
	@ObservedObject var library: LibraryStore
	@ObservedObject var pdf: PDFController
	var toastCenter: EnhancedToastCenter
	var open: (LibraryItem) -> Void
	@State private var filter = ""
    @State private var selection = Set<UUID>()
    @State private var sort: SortOption = .recent
    @State private var showingDeleteConfirmation = false
    @State private var loadingItemID: UUID?
    @State private var showingLibrarySearch = false
    @State private var cachedSortedFiltered: [LibraryItem] = []
    @State private var quickLookURL: URL?
    @State private var isDropTargeted = false
    @State private var isImporting = false
    @AppStorage("library.sortOrder") private var persistedSortOrder: String = "recent"
	
	var body: some View {
		VStack(spacing: 0) {
            HStack {
                Button(action: { importFromFinder() }) { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help("Import PDFs…")
                    .accessibilityIdentifier("libraryImportButton")
                    .accessibilityLabel("Import PDFs")
                if !selection.isEmpty {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove Selected", systemImage: "trash")
                    }
                    .help("Remove selected from Library")
                    .accessibilityIdentifier("libraryRemoveSelected")
                }
                Spacer()
                Menu {
                    Section("Sort") {
                        Picker("Sort", selection: $sort) {
                            Text("Recently Added").tag(SortOption.recent)
                            Text("Title (A–Z)").tag(SortOption.titleAZ)
                            Text("Title (Z–A)").tag(SortOption.titleZA)
                        }
                    }
                    Section {
                        Button {
                            showingLibrarySearch = true
                        } label: {
                            Label("Search All PDFs", systemImage: "text.magnifyingglass")
                        }
                    }
                    if !library.recentlyRemoved.isEmpty {
                        Section("Recently Removed") {
                            ForEach(library.recentlyRemoved) { item in
                                Button {
                                    library.restoreItem(item)
                                } label: {
                                    Label(item.title, systemImage: "arrow.uturn.backward")
                                }
                            }
                            Divider()
                            Button {
                                library.restoreAllRecentlyRemoved()
                            } label: {
                                Label("Restore All", systemImage: "arrow.uturn.backward.circle")
                            }
                            Button(role: .destructive) {
                                library.clearRecentlyRemoved()
                            } label: {
                                Label("Clear List", systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("libraryOverflowMenu")
            }
			.padding(DS.Spacing.sm)
			Divider()
            if library.items.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: "books.vertical")
                } description: {
                    Text("Import PDFs to build your library.")
                } actions: {
                    Button("Import PDF…") { importFromFinder() }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityIdentifier("libraryEmptyImport")
            } else {
                List(selection: $selection) {
                    ForEach(cachedSortedFiltered) { item in
                        LibraryItemRow(
                            item: item,
                            pdf: pdf,
                            isLoading: loadingItemID == item.id && !isCurrentPDF(item),
                            isCurrent: isCurrentPDF(item),
                            onOpen: {
                                loadingItemID = item.id
                                open(item)
                            },
                            onRemove: { library.remove(item) }
                        )
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in loadDropped(providers: providers) }
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .strokeBorder(DS.Colors.accent, lineWidth: 3)
                            .background(DS.Colors.accent.opacity(0.05))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if isImporting {
                        VStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                            Text("Importing…")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
                .onKeyPress(.return) {
                    guard let firstID = selection.first,
                          let item = cachedSortedFiltered.first(where: { $0.id == firstID }) else {
                        return .ignored
                    }
                    loadingItemID = item.id
                    open(item)
                    return .handled
                }
            }
		}
		.searchable(text: $filter, placement: .sidebar, prompt: "Search library…")
		.confirmationDialog("Remove Selected Items", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
			Button("Remove \(selection.count) Item\(selection.count == 1 ? "" : "s")", role: .destructive) {
				bulkRemove()
			}
		} message: {
			Text("Are you sure? This action cannot be undone.")
		}
		.quickLookPreview($quickLookURL)
		.onKeyPress(.space) {
			guard let firstID = selection.first,
				  let item = cachedSortedFiltered.first(where: { $0.id == firstID }) else {
				return .ignored
			}
			quickLookURL = item.resolveURLFromBookmark() ?? item.url
			return .handled
		}
		.sheet(isPresented: $showingLibrarySearch) {
			LibrarySearchView(library: library) { item, pageIndex in
				open(item)
				Task { @MainActor in
					try? await Task.sleep(nanoseconds: 500_000_000)
					pdf.goToPage(pageIndex)
				}
			}
		}
		.onAppear {
			// Load persisted sort order with resilient fallback
			sort = SortOption(fromStored: persistedSortOrder)
			cachedSortedFiltered = sortedFiltered()
		}
		.onChange(of: pdf.document) { _, _ in
			loadingItemID = nil
		}
		.onReceive(pdf.pdfLoadErrorPublisher) { _ in
			loadingItemID = nil
		}
		.onChange(of: sort) { _, newSort in
			persistedSortOrder = newSort.rawValue
			cachedSortedFiltered = sortedFiltered()
		}
		.onChange(of: filter) { _, _ in
			cachedSortedFiltered = sortedFiltered()
		}
		.onChange(of: library.items) { _, _ in
			cachedSortedFiltered = sortedFiltered()
		}
	}
	
	func isCurrentPDF(_ item: LibraryItem) -> Bool { pdf.document?.documentURL == item.url }
	
	func filtered() -> [LibraryItem] {
		guard !filter.isEmpty else { return library.items }
		return library.items.filter { $0.title.localizedCaseInsensitiveContains(filter) || $0.url.lastPathComponent.localizedCaseInsensitiveContains(filter) }
	}

    func sortedFiltered() -> [LibraryItem] {
        let base = filtered()
        switch sort {
        case .recent: return base.sorted { $0.addedAt > $1.addedAt }
        case .titleAZ: return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA: return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }
	
        func importFromFinder() {
            Task {
                let urls = await FileService.openPDF(multiple: true)
                if !urls.isEmpty {
                    importURLs(urls)
                }
            }
        }
        
        private func importURLs(_ urls: [URL]) {
            isImporting = true
            let urlsToImport = urls
            Task.detached(priority: .userInitiated) { @Sendable in
                var valid: [URL] = []
                var errors: [String] = []

                for url in urlsToImport {
                    guard url.pathExtension.lowercased() == "pdf" else {
                        errors.append("\(url.lastPathComponent) is not a PDF file")
                        continue
                    }
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        errors.append("\(url.lastPathComponent) not found")
                        continue
                    }
                    guard let handle = try? FileHandle(forReadingFrom: url) else {
                        errors.append("\(url.lastPathComponent) is not readable")
                        continue
                    }
                    let header = handle.readData(ofLength: 5)
                    try? handle.close()
                    guard header.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) else { // %PDF-
                        errors.append("\(url.lastPathComponent) appears to be corrupted")
                        continue
                    }
                    valid.append(url)
                }

                await MainActor.run {
                    isImporting = false
                    if !valid.isEmpty {
                        library.add(urls: valid)
                        toastCenter.showSuccess(
                            "Import Complete",
                            "Successfully imported \(valid.count) PDF\(valid.count == 1 ? "" : "s")"
                        )
                    }
                    if !errors.isEmpty {
                        toastCenter.showError(
                            "Import Failed",
                            "Failed to import \(errors.count) file\(errors.count == 1 ? "" : "s"): \(errors.joined(separator: "\n"))"
                        )
                    }
                }
            }
        }
	
	func loadDropped(providers: [NSItemProvider]) -> Bool {
		var any = false
		let group = DispatchGroup()
		let collectQueue = DispatchQueue(label: "devreader.drop-collect")
		var urls: [URL] = []
		for p in providers where p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
			group.enter()
			p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
				defer { group.leave() }
				if let url = data as? URL {
					collectQueue.sync { urls.append(url) }
				}
			}
			any = true
		}
		group.notify(queue: .main) {
			if !urls.isEmpty {
				importURLs(urls)
			}
		}
		return any
	}

    func bulkRemove() {
        library.remove(ids: selection)
        selection.removeAll()
    }
}

// Sort options — raw values are persisted; do not rename without migration.
enum SortOption: String, CaseIterable {
    case recent = "recent"
    case titleAZ = "titleAZ"
    case titleZA = "titleZA"

    var label: String {
        switch self {
        case .recent: return "Recent"
        case .titleAZ: return "A–Z"
        case .titleZA: return "Z–A"
        }
    }

    /// Resilient initializer for persisted values; defaults to `.recent` for unknown strings.
    init(fromStored rawValue: String) {
        self = SortOption(rawValue: rawValue) ?? .recent
    }
}

// MARK: - Reading Progress Bar

/// A thin linear progress bar showing how far a PDF has been read.
/// Extracted row view for each library item to reduce body type-check complexity.
private struct LibraryItemRow: View {
    let item: LibraryItem
    @ObservedObject var pdf: PDFController
    let isLoading: Bool
    let isCurrent: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.title)
                    Text(item.url.lastPathComponent).font(DS.Typography.caption).foregroundStyle(DS.Colors.secondary)
                    ReadingProgressBar(item: item, pdf: pdf)
                }
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if isCurrent {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Colors.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("PDF: \(item.title)")
        .accessibilityHint("Added on \(DateFormatter.localizedString(from: item.addedAt, dateStyle: .short, timeStyle: .none)). Tap to open this PDF")
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            .accessibilityLabel("Reveal in Finder")
            .accessibilityHint("Show this PDF file in Finder")

            Button("Remove from Library") {
                onRemove()
            }
            .accessibilityLabel("Remove from Library")
            .accessibilityHint("Remove this PDF from your library")
        }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
    }
}

/// Uses live progress from PDFController for the currently open PDF,
/// and falls back to persisted maxPageReached data for other items.
private struct ReadingProgressBar: View {
    let item: LibraryItem
    @ObservedObject var pdf: PDFController

    private var isCurrentPDF: Bool {
        pdf.document?.documentURL == item.url
    }

    private var progress: Double? {
        if isCurrentPDF {
            return pdf.readingProgress
        }
        // Load persisted progress for non-active PDFs using stored maxPage and totalPages
        let maxKey = PersistenceService.key("DevReader.MaxPageReached.v1", for: item.url)
        guard let savedMax = PersistenceService.loadInt(forKey: maxKey) else { return nil }
        let pagesKey = PersistenceService.key("DevReader.TotalPages.v1", for: item.url)
        guard let totalPages = PersistenceService.loadInt(forKey: pagesKey), totalPages > 0 else { return nil }
        return min(1.0, Double(savedMax + 1) / Double(totalPages))
    }

    var body: some View {
        if let progress, progress > 0 {
            ProgressView(value: progress)
                .tint(progress >= 1.0 ? DS.Colors.success : DS.Colors.accent)
                .scaleEffect(y: 0.5, anchor: .center)
                .accessibilityLabel("Reading progress: \(Int(progress * 100))%")
        }
    }
}
