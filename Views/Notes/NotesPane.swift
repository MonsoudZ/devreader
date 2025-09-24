import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit

struct NotesPane: View {
	@ObservedObject var pdf: PDFController
	@ObservedObject var notes: NotesStore
	@State private var filter = ""
	@State private var showPageNotes = true
    // Export filters
    @State private var selectedTag: String? = nil
    @State private var filterBookmarks = false
    @State private var useDateFilter = false
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var dateTo: Date = Date()
    @AppStorage("notes.exportPresets") private var exportPresetsRaw: String = "[]"
    @State private var currentPresetName: String = ""
	
	var body: some View {
		VStack(spacing: 0) {
            HStack {
				TextField("Filter notes…", text: $filter)
					.accessibilityLabel("Filter notes")
					.accessibilityHint("Enter text to filter notes by content")
				Spacer()
				Button("Add Note") { addCustomNote() }.buttonStyle(.bordered)
					.accessibilityLabel("Add Note")
					.accessibilityHint("Create a new note")
                Button("Export MD") { exportMarkdown() }
					.accessibilityLabel("Export Markdown")
					.accessibilityHint("Export notes to Markdown format")
			}.padding(8)

            // Export filters UI
            HStack(spacing: 12) {
                // Tag filter
                Menu {
                    Button("All Tags") { selectedTag = nil }
                    ForEach(Array(notes.availableTags).sorted(), id: \.self) { tag in
                        Button(tag) { selectedTag = tag }
                    }
                } label: {
                    HStack {
                        Image(systemName: "tag")
                        Text(selectedTag ?? "All Tags")
                    }
                }
                Toggle("Bookmarks", isOn: $filterBookmarks)
                    .toggleStyle(.switch)
                Toggle("Date Range", isOn: $useDateFilter)
                    .toggleStyle(.switch)
                if useDateFilter {
                    DatePicker("From", selection: $dateFrom, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("To", selection: $dateTo, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Spacer()
                Menu("Presets") {
                    Button("Save as Preset…") { promptSavePreset() }
                    let presets = loadPresets()
                    if presets.isEmpty { Text("No presets").foregroundStyle(.secondary) }
                    ForEach(presets, id: \.name) { preset in
                        Button(preset.name) { applyPreset(preset) }
                    }
                    if !presets.isEmpty {
                        Divider()
                        ForEach(loadPresets(), id: \.name) { preset in
                            Button("Delete ‘\(preset.name)’") { deletePreset(named: preset.name) }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
			
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
					ForEach(filteredGroups, id: \.key) { group in
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
	
	private var filteredGroups: [(key: String, value: [NoteItem])] {
		let groups = notes.groupedByChapter().map { (key: $0.key, value: $0.value.filter { filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter) }) }
		return groups.filter { !$0.value.isEmpty }
	}
	
	func addCustomNote() {
		guard pdf.document != nil else { return }
		let pageIndex = pdf.currentPageIndex
		let chapter = pdf.outlineMap[pageIndex] ?? ""
		let note = NoteItem(text: "", pageIndex: pageIndex, chapter: chapter)
		notes.add(note)
		// Auto-start editing the new note
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			// This will be handled by the NoteRow's auto-edit functionality
		}
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
        let allowedPages: Set<Int>? = filterBookmarks ? Set(pdf.bookmarks) : nil
        for p in pages {
			let text = notes.pageNotes[p]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let include = (allowedPages == nil) || allowedPages!.contains(p)
            if include, !text.isEmpty { md += "### Page \(p+1)\n\n\(text)\n\n" }
		}
        // Highlight notes with filters: tag/date/bookmarks
        let filteredItems = notes.items.filter { item in
            let tagOk = selectedTag == nil || item.tags.contains(selectedTag!)
            let dateOk = !useDateFilter || (item.date >= startOfDay(dateFrom) && item.date <= endOfDay(dateTo))
            let bmOk = (allowedPages == nil) || allowedPages!.contains(item.pageIndex)
            return tagOk && dateOk && bmOk
        }
        let grouped = Dictionary(grouping: filteredItems) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
            .sorted { $0.key < $1.key }
        for g in grouped {
			md += "## \(g.key)\n\n"
			for n in g.value { md += "- p.\(n.pageIndex + 1) (\(df.string(from: n.date))): \(n.text)\n" }
			md += "\n"
		}
        if let url = FileService.savePlainText(defaultName: "DevReader-Notes.md") {
            try? md.data(using: .utf8)?.write(to: url)
        }
	}
    private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
    private func endOfDay(_ d: Date) -> Date {
        let start = Calendar.current.startOfDay(for: d)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? d
    }
    // MARK: - Presets
    struct ExportPreset: Codable, Equatable { let name: String; let tag: String?; let bookmarks: Bool; let useDate: Bool; let from: Date; let to: Date }
    private func loadPresets() -> [ExportPreset] { (try? JSONDecoder().decode([ExportPreset].self, from: Data(exportPresetsRaw.utf8))) ?? [] }
    private func savePresets(_ presets: [ExportPreset]) {
        if let data = try? JSONEncoder().encode(presets), let s = String(data: data, encoding: .utf8) { exportPresetsRaw = s }
    }
    private func promptSavePreset() {
        let name = prompt(text: "Preset name:")
        guard let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var presets = loadPresets().filter { $0.name != name }
        presets.append(ExportPreset(name: name, tag: selectedTag, bookmarks: filterBookmarks, useDate: useDateFilter, from: dateFrom, to: dateTo))
        savePresets(presets)
    }
    private func applyPreset(_ p: ExportPreset) {
        selectedTag = p.tag
        filterBookmarks = p.bookmarks
        useDateFilter = p.useDate
        dateFrom = p.from
        dateTo = p.to
    }
    private func deletePreset(named: String) { savePresets(loadPresets().filter { $0.name != named }) }
    private func prompt(text: String) -> String? {
        let alert = NSAlert(); alert.messageText = text; alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = input
        let res = alert.runModal()
        return res == .alertFirstButtonReturn ? input.stringValue : nil
    }
}
