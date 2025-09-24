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
                    Button(role: .destructive) { bulkRemove() } label: { Label("Remove Selected", systemImage: "trash") }
                        .help("Remove selected from Library")
                        .accessibilityLabel("Remove selected items")
                        .accessibilityHint("Remove selected PDFs from library")
                }
            }
			.padding(8)
			Divider()
            List(selection: $selection) {
                ForEach(sortedFiltered()) { item in
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
					.contextMenu {
						Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
						Button("Remove from Library") { library.remove(item) }
					}
                    .onDrag { NSItemProvider(object: item.url as NSURL) }
				}
			}
			.onDrop(of: [.fileURL], isTargeted: nil) { providers in loadDropped(providers: providers) }
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
            let urls = FileService.openPDF(multiple: true)
            if !urls.isEmpty { library.add(urls: urls) }
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
		group.notify(queue: .main) { if !urls.isEmpty { library.add(urls: urls) } }
		return any
	}

    func bulkRemove() {
        library.remove(ids: selection)
        selection.removeAll()
    }
}

enum SortOption { case recent, titleAZ, titleZA }
