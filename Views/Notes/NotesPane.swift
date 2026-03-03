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
	@State private var isExporting = false
	@State private var exportProgress: Double = 0.0
	@State private var exportStatus: String = ""
	@State private var showingPresetSheet = false
	@State private var presetName = ""
	
	@State private var showingFilterPopover = false

	private var hasActiveFilters: Bool {
		selectedTag != nil || filterBookmarks || useDateFilter
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 6) {
				TextField("Filter notes…", text: $filter)
					.accessibilityIdentifier("notesFilterField")
					.accessibilityLabel("Filter notes")
					.accessibilityHint("Enter text to filter notes by content")
				Spacer()
				Button("Add Note") { addCustomNote() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.accessibilityIdentifier("addNoteButton")
					.accessibilityLabel("Add Note")
					.accessibilityHint("Create a new note")
				Button {
					showingFilterPopover.toggle()
				} label: {
					Label("Filter", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.popover(isPresented: $showingFilterPopover) {
					filterPopoverContent
				}
				.accessibilityIdentifier("notesFilterOptions")
				.accessibilityLabel("Filter options")
				.accessibilityHint("Show export and filter options")
				Button {
					Task { await exportMarkdownAsync() }
				} label: {
					Label("Export MD", systemImage: "square.and.arrow.up")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("exportMarkdown")
				.accessibilityLabel("Export Markdown")
				.accessibilityHint("Export notes to Markdown format")
				.disabled(isExporting)
			}.padding(8)
			
			// Export progress indicator
			if isExporting {
				VStack(spacing: 8) {
					HStack {
						ProgressView(value: exportProgress, total: 1.0)
							.progressViewStyle(.linear)
						Text("\(Int(exportProgress * 100))%")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Text(exportStatus)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.horizontal, 8)
				.padding(.bottom, 4)
			}
			
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
					if !pdf.bookmarkManager.bookmarks.isEmpty {
						VStack(alignment: .leading, spacing: 6) {
							Text("Bookmarks").font(.headline)
							ForEach(Array(pdf.bookmarkManager.bookmarks).sorted(), id: \.self) { pageIndex in
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
	
	private var filterPopoverContent: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Export Filters")
				.font(.headline)

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
			.accessibilityIdentifier("tagFilterMenu")
			.accessibilityLabel("Filter by tag")
			.accessibilityHint("Select a tag to filter notes, or choose All Tags to show all notes")

			Toggle("Bookmarks only", isOn: $filterBookmarks)
				.toggleStyle(.switch)
				.accessibilityIdentifier("bookmarksOnlyToggle")
				.accessibilityLabel("Filter bookmarks")
				.accessibilityHint("Show only notes from bookmarked pages")

			Toggle("Date Range", isOn: $useDateFilter)
				.toggleStyle(.switch)
				.accessibilityIdentifier("dateRangeToggle")
				.accessibilityLabel("Filter by date range")
				.accessibilityHint("Show only notes within the specified date range")

			if useDateFilter {
				DatePicker("From", selection: $dateFrom, displayedComponents: .date)
					.datePickerStyle(.compact)
				DatePicker("To", selection: $dateTo, displayedComponents: .date)
					.datePickerStyle(.compact)
			}

			Divider()

			Menu("Presets") {
				Button("Save as Preset\u{2026}") {
					presetName = ""
					showingPresetSheet = true
				}
				let presets = loadPresets()
				if presets.isEmpty { Text("No presets").foregroundStyle(.secondary) }
				ForEach(presets, id: \.name) { preset in
					Button(preset.name) { applyPreset(preset) }
				}
				if !presets.isEmpty {
					Divider()
					ForEach(loadPresets(), id: \.name) { preset in
						Button("Delete '\(preset.name)'") { deletePreset(named: preset.name) }
					}
				}
			}
			.accessibilityIdentifier("presetsMenu")
			.accessibilityLabel("Export presets")
			.accessibilityHint("Save, load, or delete export filter presets")
		}
		.padding(16)
		.frame(width: 280)
	}

	private var filteredGroups: [(key: String, value: [NoteItem])] {
		let groups = notes.groupedByChapter().map { (key: $0.key, value: $0.value.filter { filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter) }) }
		return groups.filter { !$0.value.isEmpty }
	}
	
	func addCustomNote() {
		guard pdf.document != nil else { return }
		let pageIndex = pdf.currentPageIndex
		let chapter = pdf.outlineManager.outlineMap[pageIndex] ?? ""
		let note = NoteItem(text: "", pageIndex: pageIndex, chapter: chapter)
		notes.add(note)
		// NoteRow auto-starts editing for newly created notes
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
		.sheet(isPresented: $showingPresetSheet) {
			PresetSaveSheet(
				presetName: $presetName,
				isPresented: $showingPresetSheet,
				onSave: { name in
					savePreset(name: name)
				}
			)
		}
	}
	
	func exportMarkdownAsync() async {
		// Present save panel on main thread FIRST to avoid runModal() inside Task.detached
		guard let saveURL = FileService.savePlainText(defaultName: "DevReader-Notes.md") else { return }

		isExporting = true
		exportProgress = 0.0
		exportStatus = "Preparing export..."

		// Capture current filter values on main actor
		let currentSelectedTag = selectedTag
		let currentFilterBookmarks = filterBookmarks
		let currentUseDateFilter = useDateFilter
		let currentDateFrom = dateFrom
		let currentDateTo = dateTo
		let currentPageNotes = notes.pageNotes
		let currentNotesItems = notes.items
		let currentBookmarks = pdf.bookmarkManager.bookmarks

		// Move heavy processing to background thread
		await Task.detached(priority: .userInitiated) { @Sendable in
			let df = DateFormatter()
			df.dateStyle = .short
			df.timeStyle = .short

			var md = "# Notes Export\n\n"

			await MainActor.run {
				exportProgress = 0.1
				exportStatus = "Processing page notes..."
			}

			md += "## Page Notes\n\n"
			let pages = currentPageNotes.keys.sorted()
			let allowedPages: Set<Int>? = currentFilterBookmarks ? Set(currentBookmarks) : nil

			for (index, p) in pages.enumerated() {
				let text = currentPageNotes[p]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
				let include = allowedPages.map { $0.contains(p) } ?? true
				if include, !text.isEmpty {
					md += "### Page \(p+1)\n\n\(text)\n\n"
				}

				// Update progress
				await MainActor.run {
					exportProgress = 0.1 + (0.3 * Double(index) / Double(pages.count))
				}
			}

			await MainActor.run {
				exportProgress = 0.4
				exportStatus = "Processing notes..."
			}

			// Filter notes with tag/date/bookmark filters
			let filteredItems = currentNotesItems.filter { item in
				let tagOk = currentSelectedTag.map { item.tags.contains($0) } ?? true
				let dateOk = !currentUseDateFilter || (item.date >= Calendar.current.startOfDay(for: currentDateFrom) && item.date <= Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: currentDateTo)) ?? currentDateTo)
				let bmOk = allowedPages.map { $0.contains(item.pageIndex) } ?? true
				return tagOk && dateOk && bmOk
			}

			await MainActor.run {
				exportProgress = 0.6
				exportStatus = "Grouping notes by chapter..."
			}

			let grouped = Dictionary(grouping: filteredItems) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
				.sorted { $0.key < $1.key }

			for (index, g) in grouped.enumerated() {
				md += "## \(g.key)\n\n"
				for n in g.value {
					md += "- p.\(n.pageIndex + 1) (\(df.string(from: n.date))): \(n.text)\n"
				}
				md += "\n"

				// Update progress
				await MainActor.run {
					exportProgress = 0.6 + (0.3 * Double(index) / Double(grouped.count))
				}
			}

			await MainActor.run {
				exportProgress = 0.9
				exportStatus = "Saving file..."
			}

			// Write to the URL chosen earlier
			do {
				try md.data(using: .utf8)?.write(to: saveURL)
			} catch {
				await MainActor.run {
					exportProgress = 0.0
					exportStatus = "Export failed: \(error.localizedDescription)"
				}
				return
			}

			await MainActor.run {
				exportProgress = 1.0
				exportStatus = "Export completed successfully!"

				// Show success toast
				NotificationCenter.default.post(
					name: .showToast,
					object: ToastMessage(
						message: "Notes exported to \(saveURL.lastPathComponent)",
						type: .success
					)
				)
			}
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			await MainActor.run {
				isExporting = false
				exportProgress = 0.0
				exportStatus = ""
			}
		}.value
	}
    // MARK: - Presets
    struct ExportPreset: Codable, Equatable { let name: String; let tag: String?; let bookmarks: Bool; let useDate: Bool; let from: Date; let to: Date }
    private func loadPresets() -> [ExportPreset] { (try? JSONDecoder().decode([ExportPreset].self, from: Data(exportPresetsRaw.utf8))) ?? [] }
    private func savePresets(_ presets: [ExportPreset]) {
        if let data = try? JSONEncoder().encode(presets), let s = String(data: data, encoding: .utf8) { exportPresetsRaw = s }
    }
    private func savePreset(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
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
}

// MARK: - PresetSaveSheet

struct PresetSaveSheet: View {
    @Binding var presetName: String
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Export Preset")
                .font(.headline)
            
            Text("Enter a name for this export filter preset:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("Preset name", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("presetNameField")
                .accessibilityLabel("Preset name")
                .accessibilityHint("Enter a name for the export filter preset")
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("presetCancel")
                .accessibilityLabel("Cancel")
                .accessibilityHint("Cancel saving the preset")
                
                Button("Save") {
                    onSave(presetName)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("presetSave")
                .accessibilityLabel("Save preset")
                .accessibilityHint("Save the export filter preset with the entered name")
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
