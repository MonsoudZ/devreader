import SwiftUI

struct NoteRow: View {
	var item: NoteItem
	var jump: () -> Void
	@ObservedObject var notes: NotesStore
	@State private var showingTagEditor = false
	@State private var newTag = ""
	@State private var isEditing = false
	@State private var editingText = ""
	@State private var editingTitle = ""
	@State private var isNewNote = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 4) {
					if isEditing {
						VStack(alignment: .leading, spacing: 4) {
							TextField("Note title (optional)", text: $editingTitle)
								.textFieldStyle(.roundedBorder)
								.font(.headline)
							TextEditor(text: $editingText)
								.font(.body)
								.frame(minHeight: 60)
								.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
						}
					} else {
						VStack(alignment: .leading, spacing: 2) {
							if !item.text.isEmpty {
								Text(item.text).font(.body)
							} else {
								Text("Empty note - click Edit to add content").font(.body).foregroundStyle(.secondary).italic()
							}
						}
					}
					Text("Page \(item.pageIndex + 1)").font(.caption).foregroundStyle(.secondary)
				}
				Spacer()
				if isEditing {
					VStack(spacing: 4) {
						Button("Save") { saveEdit() }
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Save note changes")
							.accessibilityHint("Save the edited note content and title")
						Button("Cancel") { cancelEdit() }
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Cancel editing")
							.accessibilityHint("Discard changes and exit edit mode")
					}
				} else {
					VStack(spacing: 4) {
						Button("Edit") { startEdit() }
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Edit note")
							.accessibilityHint("Edit the note content and title")
						Button("Go") { jump() }
							.accessibilityLabel("Go to page")
							.accessibilityHint("Jump to page \(item.pageIndex + 1) in the PDF")
					}
				}
			}
			
			// Tags section
			VStack(alignment: .leading, spacing: 4) {
				if isEditing {
					HStack {
						TextField("Add tag...", text: $newTag)
							.textFieldStyle(.roundedBorder)
							.onSubmit { addTag() }
							.accessibilityLabel("Add tag")
							.accessibilityHint("Enter a new tag for this note")
						Button("Add") { addTag() }
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Add tag")
							.accessibilityHint("Add the entered tag to this note")
					}
				}
				
				if !item.tags.isEmpty {
					HStack {
						ForEach(item.tags, id: \.self) { tag in
							HStack(spacing: 2) {
								Text(tag)
									.font(.caption)
									.padding(.horizontal, 6)
									.padding(.vertical, 2)
									.background(Color.blue.opacity(0.2))
									.cornerRadius(4)
								if isEditing {
									Button("×") { notes.removeTag(tag, from: item) }
										.font(.caption)
										.foregroundStyle(.red)
										.accessibilityLabel("Remove tag \(tag)")
										.accessibilityHint("Remove this tag from the note")
								}
							}
						}
						Spacer()
					}
				}
				
				if !isEditing && item.tags.isEmpty {
					HStack {
						Button("+ Add Tag") { showingTagEditor = true }
							.font(.caption)
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Add tag")
							.accessibilityHint("Add a tag to this note")
						Spacer()
					}
				}
			}
		}
		.padding(8)
		.background(isEditing ? Color.blue.opacity(0.05) : Color.clear)
		.cornerRadius(8)
		.onAppear {
			// Auto-start editing if this is a new empty note
			if item.text.isEmpty && item.tags.isEmpty {
				isNewNote = true
				startEdit()
			}
		}
		.sheet(isPresented: $showingTagEditor) {
			VStack {
				Text("Add Tag").font(.headline)
				TextField("Enter tag name", text: $newTag).textFieldStyle(.roundedBorder)
				HStack {
					Button("Cancel") { showingTagEditor = false; newTag = "" }
					Button("Add") {
						if !newTag.isEmpty { notes.addTag(newTag, to: item) }
						showingTagEditor = false; newTag = ""
					}
				}
			}
			.padding().frame(width: 300, height: 150)
		}
	}
	
	private func startEdit() { 
		editingText = item.text
		editingTitle = "" // We don't have a title field in NoteItem yet, but this is for future expansion
		isEditing = true 
	}
	
	private func saveEdit() { 
		if let idx = notes.items.firstIndex(where: { $0.id == item.id }) { 
			notes.items[idx].text = editingText
		}
		isEditing = false
		isNewNote = false
	}
	
	private func cancelEdit() { 
		editingText = item.text
		editingTitle = ""
		isEditing = false
		if isNewNote {
			// If this was a new note and user cancels, remove it
			notes.remove(item)
		}
	}
	
	private func addTag() {
		if !newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			notes.addTag(newTag.trimmingCharacters(in: .whitespacesAndNewlines), to: item)
			newTag = ""
		}
	}
}
