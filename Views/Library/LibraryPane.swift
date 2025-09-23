import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct LibraryPane: View {
	@ObservedObject var library: LibraryStore
	@ObservedObject var pdf: PDFController
	var open: (LibraryItem) -> Void
	@State private var filter = ""
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				TextField("Search library…", text: $filter)
				Button(action: { importFromFinder() }) { Image(systemName: "plus") }.help("Import PDFs…")
			}
			.padding(8)
			Divider()
			List {
				ForEach(filtered()) { item in
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
	
	func importFromFinder() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [UTType.pdf]
		panel.allowsMultipleSelection = true
		if panel.runModal() == .OK { library.add(urls: panel.urls) }
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
}
