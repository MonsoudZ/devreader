import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct LibraryPane: View {
	@ObservedObject var library: LibraryStore
	@ObservedObject var pdf: PDFController
	var open: (LibraryItem) -> Void
	@State private var filter = ""
    @State private var selection = Set<UUID>()
    @State private var sort: SortOption = .recent
    @State private var cachedSortedItems: [LibraryItem] = []
    @State private var lastFilter = ""
    @State private var lastSort: SortOption = .recent
    @State private var showingDeleteConfirmation = false
    @AppStorage("library.sortOrder") private var persistedSortOrder: String = "recent"
	
	var body: some View {
		VStack(spacing: 0) {
            HStack {
                TextField("Search library…", text: $filter)
                    .accessibilityLabel("Search library")
                    .accessibilityHint("Enter text to search your PDF library")
                Menu("Sort") {
                    Picker("Sort", selection: $sort) {
                        Text("Recently Added").tag(SortOption.recent)
                        Text("Title (A–Z)").tag(SortOption.titleAZ)
                        Text("Title (Z–A)").tag(SortOption.titleZA)
                    }
                }
                .accessibilityLabel("Sort library")
                .accessibilityHint("Choose how to sort your PDF library")
                Button(action: { importFromFinder() }) { Image(systemName: "plus") }.help("Import PDFs…")
                    .accessibilityLabel("Import PDFs")
                    .accessibilityHint("Import new PDF files into your library")
                if !selection.isEmpty {
                    Button(role: .destructive) { 
                        showingDeleteConfirmation = true
                    } label: { 
                        Label("Remove Selected", systemImage: "trash") 
                    }
                    .help("Remove selected from Library")
                    .accessibilityLabel("Remove selected items")
                    .accessibilityHint("Remove selected PDFs from library")
                }
            }
			.padding(8)
			Divider()
            List(selection: $selection) {
                ForEach(optimizedSortedFiltered()) { item in
					Button(action: { open(item) }) {
						HStack {
							VStack(alignment: .leading, spacing: 2) {
								Text(item.title)
								Text(item.url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
							}
							Spacer()
							if isCurrentPDF(item) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
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
		.alert("Remove Selected Items", isPresented: $showingDeleteConfirmation) {
			Button("Cancel", role: .cancel) { }
			Button("Remove", role: .destructive) { 
				bulkRemove()
			}
		} message: {
			Text("Are you sure you want to remove \(selection.count) item\(selection.count == 1 ? "" : "s") from your library? This action cannot be undone.")
		}
		.onAppear {
			// Load persisted sort order
			if let persistedSort = SortOption(rawValue: persistedSortOrder) {
				sort = persistedSort
			}
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

    func optimizedSortedFiltered() -> [LibraryItem] {
        // Check if we need to recompute
        if filter != lastFilter || sort != lastSort || cachedSortedItems.isEmpty {
            updateCachedItems()
        }
        return cachedSortedItems
    }
    
    private func updateCachedItems() {
        let base = filtered()
        let sorted: [LibraryItem]
        
        switch sort {
        case .recent: 
            sorted = base.sorted { $0.addedAt > $1.addedAt }
        case .titleAZ: 
            sorted = base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA: 
            sorted = base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
        
        cachedSortedItems = sorted
        lastFilter = filter
        lastSort = sort
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
            let urls = FileService.openPDF(multiple: true)
            if !urls.isEmpty { 
                importURLs(urls)
            }
        }
        
        private func importURLs(_ urls: [URL]) {
            var successCount = 0
            var errorCount = 0
            var errorMessages: [String] = []
            
            for url in urls {
                do {
                    // Validate that it's a PDF file
                    guard url.pathExtension.lowercased() == "pdf" else {
                        errorCount += 1
                        errorMessages.append("\(url.lastPathComponent) is not a PDF file")
                        continue
                    }
                    
                    // Check if file exists and is readable
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        errorCount += 1
                        errorMessages.append("\(url.lastPathComponent) not found")
                        continue
                    }
                    
                    // Try to create a PDFDocument to validate it's not corrupted
                    if let _ = PDFDocument(url: url) {
                        library.add(urls: [url])
                        successCount += 1
                    } else {
                        errorCount += 1
                        errorMessages.append("\(url.lastPathComponent) appears to be corrupted")
                    }
                } catch {
                    errorCount += 1
                    errorMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            // Show feedback to user
            if successCount > 0 {
                NotificationCenter.default.post(
                    name: .showToast,
                    object: ToastMessage(
                        message: "Successfully imported \(successCount) PDF\(successCount == 1 ? "" : "s")",
                        type: .success
                    )
                )
            }
            
            if errorCount > 0 {
                let errorMessage = errorMessages.joined(separator: "\n")
                NotificationCenter.default.post(
                    name: .showToast,
                    object: ToastMessage(
                        message: "Failed to import \(errorCount) file\(errorCount == 1 ? "" : "s"): \(errorMessage)",
                        type: .error
                    )
                )
            }
        }
	
	func loadDropped(providers: [NSItemProvider]) -> Bool {
		var any = false
		let group = DispatchGroup()
		var urls: [URL] = []
		for p in providers where p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
			group.enter()
			p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
				defer { group.leave() }
				if let url = data as? URL { urls.append(url) }
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

enum SortOption: String, CaseIterable { 
    case recent = "recent"
    case titleAZ = "titleAZ" 
    case titleZA = "titleZA"
}
