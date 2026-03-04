import SwiftUI
import PDFKit
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
    @AppStorage("library.sortOrder") private var persistedSortOrder: String = "recent"
	
	var body: some View {
		VStack(spacing: 0) {
            HStack {
                TextField("Search library…", text: $filter)
                    .accessibilityIdentifier("librarySearchField")
                    .accessibilityLabel("Search library")
                    .accessibilityHint("Enter text to search your PDF library")
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("Recently Added").tag(SortOption.recent)
                        Text("Title (A–Z)").tag(SortOption.titleAZ)
                        Text("Title (Z–A)").tag(SortOption.titleZA)
                    }
                } label: {
                    Label(sort.label, systemImage: "arrow.up.arrow.down")
                }
                .accessibilityIdentifier("librarySortMenu")
                .accessibilityLabel("Sort library")
                .accessibilityHint("Choose how to sort your PDF library")
                Button(action: { importFromFinder() }) { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help("Import PDFs…")
                    .accessibilityIdentifier("libraryImportButton")
                    .accessibilityLabel("Import PDFs")
                    .accessibilityHint("Import new PDF files into your library")
                if !selection.isEmpty {
                    Button(role: .destructive) { 
                        showingDeleteConfirmation = true
                    } label: { 
                        Label("Remove Selected", systemImage: "trash") 
                    }
                    .help("Remove selected from Library")
                    .accessibilityIdentifier("libraryRemoveSelected")
                    .accessibilityLabel("Remove selected items")
                    .accessibilityHint("Remove selected PDFs from library")
                }
            }
			.padding(8)
			Divider()
            if library.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No PDFs in Library")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Import PDFs to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("Import PDFs...") { importFromFinder() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("libraryEmptyImport")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                List(selection: $selection) {
                    ForEach(sortedFiltered()) { item in
                        Button(action: {
                            loadingItemID = item.id
                            open(item)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text(item.url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if loadingItemID == item.id && !isCurrentPDF(item) {
                                    ProgressView().controlSize(.small)
                                } else if isCurrentPDF(item) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("PDF: \(item.title)")
                        .accessibilityHint("Added on \(DateFormatter.localizedString(from: item.addedAt, dateStyle: .short, timeStyle: .none)). Tap to open this PDF")
                        .accessibilityAddTraits(isCurrentPDF(item) ? [.isSelected] : [])
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                            .accessibilityLabel("Reveal in Finder")
                            .accessibilityHint("Show this PDF file in Finder")

                            Button("Remove from Library") {
                                library.remove(item)
                            }
                            .accessibilityLabel("Remove from Library")
                            .accessibilityHint("Remove this PDF from your library")
                        }
                        .onDrag { NSItemProvider(object: item.url as NSURL) }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in loadDropped(providers: providers) }
            }
		}
		.alert("Remove Selected Items", isPresented: $showingDeleteConfirmation) {
			Button("Cancel", role: .cancel) { }
			Button("Remove", role: .destructive) { 
				bulkRemove()
			}
		} message: {
			Text("Are you sure you want to remove \(selection.count) item\(selection.count == 1 ? "" : "s") from your library? This action cannot be undone.")
		}
		.onAppear {
			// Load persisted sort order with resilient fallback
			sort = SortOption(fromStored: persistedSortOrder)
		}
		.onChange(of: pdf.document) { _, _ in
			loadingItemID = nil
		}
		.onChange(of: sort) { _, newSort in
			// Persist sort order
			persistedSortOrder = newSort.rawValue
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
            Task.detached(priority: .userInitiated) { @Sendable in
                var validURLs: [URL] = []
                var errorMessages: [String] = []

                for url in urls {
                    // Validate that it's a PDF file
                    guard url.pathExtension.lowercased() == "pdf" else {
                        errorMessages.append("\(url.lastPathComponent) is not a PDF file")
                        continue
                    }

                    // Check if file exists and is readable
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        errorMessages.append("\(url.lastPathComponent) not found")
                        continue
                    }

                    // Validate PDF off main thread (PDFDocument init can be slow for large files)
                    if PDFDocument(url: url) != nil {
                        validURLs.append(url)
                    } else {
                        errorMessages.append("\(url.lastPathComponent) appears to be corrupted")
                    }
                }

                await MainActor.run {
                    // Add validated PDFs to library on main thread
                    if !validURLs.isEmpty {
                        library.add(urls: validURLs)
                        toastCenter.showSuccess(
                            "Import Complete",
                            "Successfully imported \(validURLs.count) PDF\(validURLs.count == 1 ? "" : "s")"
                        )
                    }

                    if !errorMessages.isEmpty {
                        let errorMessage = errorMessages.joined(separator: "\n")
                        toastCenter.showError(
                            "Import Failed",
                            "Failed to import \(errorMessages.count) file\(errorMessages.count == 1 ? "" : "s"): \(errorMessage)"
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
