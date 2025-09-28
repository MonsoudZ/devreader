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
	@State private var isExporting = false
	@State private var exportProgress: Double = 0.0
	@State private var exportStatus: String = ""
	@State private var showingPresetSheet = false
	@State private var presetName = ""
	
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
                Button("Export MD") { 
					Task { await exportMarkdownAsync() }
				}
					.accessibilityLabel("Export Markdown")
					.accessibilityHint("Export notes to Markdown format")
					.disabled(isExporting)
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
                .accessibilityLabel("Filter by tag")
                .accessibilityHint("Select a tag to filter notes, or choose All Tags to show all notes")
                Toggle("Bookmarks", isOn: $filterBookmarks)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Filter bookmarks")
                    .accessibilityHint("Show only notes from bookmarked pages")
                Toggle("Date Range", isOn: $useDateFilter)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Filter by date range")
                    .accessibilityHint("Show only notes within the specified date range")
                if useDateFilter {
                    DatePicker("From", selection: $dateFrom, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("To", selection: $dateTo, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Spacer()
                Menu("Presets") {
                    Button("Save as Preset…") { 
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
                .accessibilityLabel("Export presets")
                .accessibilityHint("Save, load, or delete export filter presets")
			}
			.padding(.horizontal, 8)
			.padding(.bottom, 4)
			
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
		await MainActor.run {
			isExporting = true
			exportProgress = 0.0
			exportStatus = "Preparing export..."
		}
		
		// Capture current filter values on main actor
		let currentSelectedTag = selectedTag
		let currentFilterBookmarks = filterBookmarks
		let currentUseDateFilter = useDateFilter
		let currentDateFrom = dateFrom
		let currentDateTo = dateTo
		let currentPageNotes = notes.pageNotes
		let currentNotesItems = notes.items
		let currentBookmarks = pdf.bookmarks
		
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
				let include = (allowedPages == nil) || allowedPages!.contains(p)
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
				let tagOk = currentSelectedTag == nil || item.tags.contains(currentSelectedTag!)
				let dateOk = !currentUseDateFilter || (item.date >= Calendar.current.startOfDay(for: currentDateFrom) && item.date <= Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: currentDateTo)) ?? currentDateTo)
				let bmOk = (allowedPages == nil) || allowedPages!.contains(item.pageIndex)
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
			
			// Save file
			let url = await MainActor.run { FileService.savePlainText(defaultName: "DevReader-Notes.md") }
			if let url = url {
				try? md.data(using: .utf8)?.write(to: url)
				
				await MainActor.run {
					exportProgress = 1.0
					exportStatus = "Export completed successfully!"
					
					// Show success toast
					NotificationCenter.default.post(
						name: .showToast,
						object: ToastMessage(
							message: "Notes exported to \(url.lastPathComponent)",
							type: .success
						)
					)
					
					// Reset after delay
					DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
						isExporting = false
						exportProgress = 0.0
						exportStatus = ""
					}
				}
			} else {
				await MainActor.run {
					exportStatus = "Export failed - could not save file"
					DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
						isExporting = false
						exportProgress = 0.0
						exportStatus = ""
					}
				}
			}
		}.value
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
                .accessibilityLabel("Preset name")
                .accessibilityHint("Enter a name for the export filter preset")
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")
                .accessibilityHint("Cancel saving the preset")
                
                Button("Save") {
                    onSave(presetName)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Save preset")
                .accessibilityHint("Save the export filter preset with the entered name")
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
