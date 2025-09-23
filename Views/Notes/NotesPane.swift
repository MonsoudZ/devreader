import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit

struct NotesPane: View {
	@ObservedObject var pdf: PDFController
	@ObservedObject var notes: NotesStore
	@State private var filter = ""
	@State private var showPageNotes = true
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				TextField("Filter notes…", text: $filter)
				Spacer()
				Button("Add Note") { addCustomNote() }.buttonStyle(.bordered)
				Button("Export MD") { exportMarkdown() }
			}.padding(8)
			
			if let doc = pdf.document, let url = doc.documentURL {
				HStack {
					Image(systemName: "doc.text.fill").foregroundStyle(.blue)
					Text(url.deletingPathExtension().lastPathComponent).font(.caption).foregroundStyle(.secondary)
					Spacer()
				}
				.padding(.horizontal, 8).padding(.bottom, 4)
			}
			
			Divider()
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 12) {
					if showPageNotes { pageNotesEditor }
					Divider()
					if !pdf.bookmarks.isEmpty {
						VStack(alignment: .leading, spacing: 6) {
							Text("Bookmarks").font(.headline)
							ForEach(Array(pdf.bookmarks).sorted(), id: \.self) { pageIndex in
								HStack {
									Image(systemName: "bookmark.fill").foregroundStyle(.blue)
									Text("Page \(pageIndex + 1)").font(.body)
									Spacer()
									Button("Go") { pdf.goToPage(pageIndex) }
										.buttonStyle(.bordered).controlSize(.small)
								}
								.padding(.horizontal, 8).padding(.vertical, 4)
								.background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
							}
						}
						.padding(.horizontal, 8)
						Divider()
					}
					ForEach(filteredGroups(), id: \.key) { group in
						VStack(alignment: .leading, spacing: 6) {
							Text(group.key).font(.headline)
							ForEach(group.value) { item in
								NoteRow(item: item, jump: { pdf.goToPage(item.pageIndex) }, notes: notes)
							}
						}
						.padding(.horizontal, 8)
						Divider()
					}
				}
			}
		}
	}
	
	func filteredGroups() -> [(key: String, value: [NoteItem])] {
		let groups = notes.groupedByChapter().map { (key: $0.key, value: $0.value.filter { filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter) }) }
		return groups.filter { !$0.value.isEmpty }
	}
	
	func addCustomNote() {
		guard pdf.document != nil else { return }
		let pageIndex = pdf.currentPageIndex
		let chapter = pdf.outlineMap[pageIndex] ?? ""
		let note = NoteItem(text: "Custom note - click to edit", pageIndex: pageIndex, chapter: chapter)
		notes.add(note)
	}
	
	var pageNotesEditor: some View {
		VStack(alignment: .leading, spacing: 4) {
			if pdf.document != nil {
				let page = pdf.currentPageIndex + 1
				Text("Page Notes – p.\(page)").font(.headline)
				TextEditor(text: Binding(
					get: { notes.note(for: pdf.currentPageIndex) },
					set: { notes.setNote($0, for: pdf.currentPageIndex) }
				))
				.font(.system(.body, design: .monospaced))
				.frame(minHeight: 180)
				.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
				Text("Tips: Use Markdown. Export bundles these too.")
					.font(.caption).foregroundStyle(.secondary)
			} else {
				Text("Open a PDF to edit page notes.").foregroundStyle(.secondary)
			}
		}
		.padding(8)
	}
	
	func exportMarkdown() {
		let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
		var md = "# Notes Export\n\n"
		md += "## Page Notes\n\n"
		let pages = notes.pageNotes.keys.sorted()
		for p in pages {
			let text = notes.pageNotes[p]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			if !text.isEmpty { md += "### Page \(p+1)\n\n\(text)\n\n" }
		}
		for g in notes.groupedByChapter() {
			md += "## \(g.key)\n\n"
			for n in g.value { md += "- p.\(n.pageIndex + 1) (\(df.string(from: n.date))): \(n.text)\n" }
			md += "\n"
		}
		let panel = NSSavePanel()
		panel.nameFieldStringValue = "DevReader-Notes.md"
		panel.allowedContentTypes = [UTType.plainText]
		if panel.runModal() == .OK, let url = panel.url { try? md.data(using: .utf8)?.write(to: url) }
	}
}
