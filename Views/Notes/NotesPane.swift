import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit

struct NotesPane: View {
	@ObservedObject var pdf: PDFController
	@ObservedObject var notes: NotesStore
	@ObservedObject var bookmarkManager: PDFBookmarkManager
	@ObservedObject var outlineManager: PDFOutlineManager
	var toastCenter: EnhancedToastCenter
	@Environment(\.undoManager) private var undoManager

	@State private var filter = ""
	@State private var showPageNotes = true
	@State private var showingTagManagement = false

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

	private var currentExportFilter: ExportFilter {
		ExportFilter(
			selectedTag: selectedTag,
			filterBookmarks: filterBookmarks,
			useDateFilter: useDateFilter,
			dateFrom: dateFrom,
			dateTo: dateTo
		)
	}

	var body: some View {
		VStack(spacing: 0) {
			notesToolbar

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
			if pdf.document == nil {
				VStack(spacing: 12) {
					Spacer()
					Image(systemName: "note.text")
						.font(.system(size: 40))
						.foregroundStyle(.secondary)
					Text("No PDF Open")
						.font(.headline)
						.foregroundStyle(.secondary)
					Text("Open a PDF to start taking notes")
						.font(.caption)
						.foregroundStyle(.tertiary)
					Spacer()
				}
				.frame(maxWidth: .infinity)
				.accessibilityElement(children: .combine)
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 12) {
						if showPageNotes { pageNotesEditor }
						Divider()
						if !bookmarkManager.bookmarks.isEmpty {
							VStack(alignment: .leading, spacing: 6) {
								Text("Bookmarks").font(.headline)
								ForEach(Array(bookmarkManager.bookmarks).sorted(), id: \.self) { pageIndex in
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
		.onChange(of: undoManager) { _, mgr in
			notes.undoManager = mgr
		}
		.onAppear {
			notes.undoManager = undoManager
		}
		.sheet(isPresented: $showingTagManagement) {
			TagManagementView(notes: notes)
		}
	}

	// MARK: - Toolbar

	private var notesToolbar: some View {
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
			if !notes.availableTags.isEmpty {
				Button {
					showingTagManagement = true
				} label: {
					Label("Tags", systemImage: "tag")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("tagManagement")
				.accessibilityLabel("Manage tags")
				.accessibilityHint("Rename, merge, or delete tags")
			}
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
				Task { await exportMarkdown() }
			} label: {
				Label("Export MD", systemImage: "square.and.arrow.up")
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.accessibilityIdentifier("exportMarkdown")
			.accessibilityLabel("Export Markdown")
			.accessibilityHint("Export notes to Markdown format")
			.disabled(isExporting)
			Button {
				PrintService.printNotes(items: notes.items, pageNotes: notes.pageNotes)
			} label: {
				Label("Print", systemImage: "printer")
					.labelStyle(.iconOnly)
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.accessibilityIdentifier("printNotes")
			.accessibilityLabel("Print notes")
			.accessibilityHint("Print all notes using the system print dialog")
		}.padding(8)
	}

	// MARK: - Filter Popover

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
				let presets = NotesExportService.loadPresets(from: exportPresetsRaw)
				if presets.isEmpty { Text("No presets").foregroundStyle(.secondary) }
				ForEach(presets, id: \.name) { preset in
					Button(preset.name) { applyPreset(preset) }
				}
				if !presets.isEmpty {
					Divider()
					ForEach(presets, id: \.name) { preset in
						Button("Delete '\(preset.name)'") {
							exportPresetsRaw = NotesExportService.deletePreset(named: preset.name, existing: exportPresetsRaw)
						}
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

	// MARK: - Helpers

	private var filteredGroups: [(key: String, value: [NoteItem])] {
		let groups = notes.groupedByChapter().map { (key: $0.key, value: $0.value.filter { filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter) }) }
		return groups.filter { !$0.value.isEmpty }
	}

	func addCustomNote() {
		guard pdf.document != nil else { return }
		let pageIndex = pdf.currentPageIndex
		let chapter = outlineManager.outlineMap[pageIndex] ?? ""
		let note = NoteItem(text: "", pageIndex: pageIndex, chapter: chapter)
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
		.sheet(isPresented: $showingPresetSheet) {
			PresetSaveSheet(
				presetName: $presetName,
				isPresented: $showingPresetSheet,
				onSave: { name in
					exportPresetsRaw = NotesExportService.savePreset(name: name, filter: currentExportFilter, existing: exportPresetsRaw)
				}
			)
		}
	}

	// MARK: - Export

	private func exportMarkdown() async {
		guard let saveURL = await FileService.savePlainText(defaultName: "DevReader-Notes.md") else { return }

		isExporting = true
		exportProgress = 0.0
		exportStatus = "Preparing export..."

		let success = await NotesExportService.exportMarkdown(
			to: saveURL,
			pageNotes: notes.pageNotes,
			items: notes.items,
			bookmarks: bookmarkManager.bookmarks,
			filter: currentExportFilter,
			onProgress: { progress, status in
				exportProgress = progress
				exportStatus = status
			}
		)

		if success {
			exportProgress = 1.0
			exportStatus = "Export completed successfully!"
			toastCenter.showSuccess("Export Complete", "Notes exported to \(saveURL.lastPathComponent)")
		}

		try? await Task.sleep(nanoseconds: 2_000_000_000)
		isExporting = false
		exportProgress = 0.0
		exportStatus = ""
	}

	private func applyPreset(_ p: ExportPreset) {
		selectedTag = p.tag
		filterBookmarks = p.bookmarks
		useDateFilter = p.useDate
		dateFrom = p.from
		dateTo = p.to
	}
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
