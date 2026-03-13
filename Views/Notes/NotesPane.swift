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
	@State private var cachedFilteredGroups: [(key: String, value: [NoteItem])] = []

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
				VStack(spacing: DS.Spacing.sm) {
					HStack {
						ProgressView(value: exportProgress, total: 1.0)
							.progressViewStyle(.linear)
						Text("\(Int(exportProgress * 100))%")
							.font(DS.Typography.caption)
							.foregroundStyle(DS.Colors.secondary)
					}
					Text(exportStatus)
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
				}
				.padding(.horizontal, DS.Spacing.sm)
				.padding(.bottom, DS.Spacing.xs)
				.accessibilityElement(children: .combine)
				.accessibilityLabel("Export progress \(Int(exportProgress * 100)) percent")
			}

			if let doc = pdf.document, let url = doc.documentURL {
				HStack {
					Image(systemName: "doc.text.fill").foregroundStyle(DS.Colors.accent)
					Text(url.deletingPathExtension().lastPathComponent).font(DS.Typography.caption).foregroundStyle(DS.Colors.secondary)
					Spacer()
				}
				.padding(.horizontal, DS.Spacing.sm).padding(.bottom, DS.Spacing.xs)
			}

			Divider()
			if pdf.document == nil {
				EmptyStateView(
					icon: "note.text",
					title: "No PDF Open",
					subtitle: "Open a PDF to start taking notes"
				)
				.accessibilityLabel("No PDF open. Open a PDF to start taking notes.")
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
						if showPageNotes { pageNotesEditor }
						Divider()
						if !bookmarkManager.bookmarks.isEmpty {
							VStack(alignment: .leading, spacing: DS.Spacing.md) {
								Text("Bookmarks").font(DS.Typography.heading)
								ForEach(Array(bookmarkManager.bookmarks).sorted(), id: \.self) { pageIndex in
									HStack {
										Image(systemName: "bookmark.fill").foregroundStyle(DS.Colors.accent)
										Text("Page \(pageIndex + 1)").font(DS.Typography.body)
										Spacer()
										Button("Go") { pdf.goToPage(pageIndex) }
											.buttonStyle(.bordered).controlSize(.small)
									}
									.padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xs)
									.background(DS.Colors.controlSurface).cornerRadius(DS.Radius.md)
								}
							}
							.padding(.horizontal, DS.Spacing.sm)
							Divider()
						}
						ForEach(cachedFilteredGroups, id: \.key) { group in
							VStack(alignment: .leading, spacing: DS.Spacing.md) {
								Text(group.key).font(DS.Typography.heading)
								ForEach(group.value) { item in
									NoteRow(item: item, jump: { pdf.goToPage(item.pageIndex) }, notes: notes)
								}
								.onMove { source, destination in
									notes.moveNotes(in: group.key, from: source, to: destination)
								}
							}
							.padding(.horizontal, DS.Spacing.sm)
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
			cachedFilteredGroups = filteredGroups
		}
		.onChange(of: notes.items) { _, _ in
			cachedFilteredGroups = filteredGroups
		}
		.onChange(of: filter) { _, _ in
			cachedFilteredGroups = filteredGroups
		}
		.sheet(isPresented: $showingTagManagement) {
			TagManagementView(notes: notes)
		}
	}

	// MARK: - Toolbar

	private var notesToolbar: some View {
		HStack(spacing: DS.Spacing.md) {
			TextField("Filter notes…", text: $filter)
				.accessibilityIdentifier("notesFilterField")
				.accessibilityLabel("Filter notes")
				.accessibilityHint("Enter text to filter notes by content")
			Spacer()
			Menu {
				Button("Blank Note") { addCustomNote() }
				Divider()
				ForEach(NoteItem.templates, id: \.name) { template in
					Button {
						addFromTemplate(template)
					} label: {
						Label(template.name, systemImage: template.icon)
					}
				}
			} label: {
				Text("Add Note")
			}
				.menuStyle(.borderedButton)
				.controlSize(.small)
				.accessibilityIdentifier("addNoteButton")
				.accessibilityLabel("Add Note")
				.accessibilityHint("Create a new note or use a template")
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
		}.padding(DS.Spacing.sm)
	}

	// MARK: - Filter Popover

	private var filterPopoverContent: some View {
		VStack(alignment: .leading, spacing: DS.Spacing.md) {
			Text("Export Filters")
				.font(DS.Typography.heading)

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
		.padding(DS.Spacing.lg)
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

	func addFromTemplate(_ template: NoteItem.Template) {
		guard pdf.document != nil else { return }
		let pageIndex = pdf.currentPageIndex
		let chapter = outlineManager.outlineMap[pageIndex] ?? ""
		let note = NoteItem.fromTemplate(template, pageIndex: pageIndex, chapter: chapter)
		notes.add(note)
	}

	var pageNotesEditor: some View {
		VStack(alignment: .leading, spacing: DS.Spacing.xs) {
			if pdf.document != nil {
				let page = pdf.currentPageIndex + 1
				Text("Page Notes – p.\(page)").font(DS.Typography.heading)
				TextEditor(text: Binding(
					get: { notes.note(for: pdf.currentPageIndex) },
					set: { notes.setNote($0, for: pdf.currentPageIndex) }
				))
				.font(DS.Typography.mono)
				.frame(minHeight: 180)
				.overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(.quaternary))
				Text("Tips: Use Markdown. Export bundles these too.")
					.font(DS.Typography.caption).foregroundStyle(DS.Colors.secondary)
			} else {
				Text("Open a PDF to edit page notes.").foregroundStyle(DS.Colors.secondary)
			}
		}
		.padding(DS.Spacing.sm)
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
		VStack(spacing: DS.Spacing.xl) {
			Text("Save Export Preset")
				.font(DS.Typography.heading)

			Text("Enter a name for this export filter preset:")
				.font(DS.Typography.subheading)
				.foregroundStyle(DS.Colors.secondary)

			TextField("Preset name", text: $presetName)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier("presetNameField")
				.accessibilityLabel("Preset name")
				.accessibilityHint("Enter a name for the export filter preset")

			HStack(spacing: DS.Spacing.md) {
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
		.padding(DS.Spacing.xl)
		.frame(width: 300)
	}
}
