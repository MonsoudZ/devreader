import SwiftUI

struct NoteRow: View {
	var item: NoteItem
	var jump: () -> Void
	@ObservedObject var notes: NotesStore
	@State private var showingTagEditor = false
	@State private var newTag = ""
	@State private var isEditing = false
	@State private var editingText = ""
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 2) {
					if isEditing {
						TextField("Edit note", text: $editingText)
							.textFieldStyle(.roundedBorder)
							.onSubmit { saveEdit() }
					} else {
						Text(item.text).font(.body)
					}
					Text("Page \(item.pageIndex + 1)").font(.caption).foregroundStyle(.secondary)
				}
				Spacer()
				if isEditing {
					Button("Save") { saveEdit() }.buttonStyle(.bordered).controlSize(.small)
					Button("Cancel") { cancelEdit() }.buttonStyle(.bordered).controlSize(.small)
				} else {
					Button("Edit") { startEdit() }.buttonStyle(.bordered).controlSize(.small)
					Button("Go") { jump() }
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
							Button("×") { notes.removeTag(tag, from: item) }
								.font(.caption)
								.foregroundStyle(.red)
						}
					}
					Spacer()
				}
			}
			
			HStack {
				Button("+ Tag") { showingTagEditor = true }.font(.caption).buttonStyle(.bordered).controlSize(.small)
				Spacer()
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
	
	private func startEdit() { editingText = item.text; isEditing = true }
	private func saveEdit() { if let idx = notes.items.firstIndex(where: { $0.id == item.id }) { notes.items[idx].text = editingText }; isEditing = false }
	private func cancelEdit() { editingText = item.text; isEditing = false }
}
