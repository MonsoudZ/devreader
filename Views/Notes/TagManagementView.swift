import SwiftUI

struct TagManagementView: View {
	@ObservedObject var notes: NotesStore
	@Environment(\.dismiss) private var dismiss

	@State private var renamingTag: String?
	@State private var renameText = ""
	@State private var mergingTag: String?
	@State private var mergeTarget: String?
	@State private var deletingTag: String?

	private var sortedTags: [String] {
		Array(notes.availableTags).sorted()
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Manage Tags")
					.font(.headline)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
			}
			.padding()

			Divider()

			if sortedTags.isEmpty {
				VStack(spacing: 8) {
					Spacer()
					Text("No tags yet")
						.foregroundStyle(.secondary)
					Spacer()
				}
			} else {
				List {
					ForEach(sortedTags, id: \.self) { tag in
						tagRow(tag)
					}
				}
			}
		}
		.frame(width: 400, height: 350)
		.alert("Delete Tag", isPresented: Binding(
			get: { deletingTag != nil },
			set: { if !$0 { deletingTag = nil } }
		)) {
			Button("Cancel", role: .cancel) { deletingTag = nil }
			Button("Delete", role: .destructive) {
				if let tag = deletingTag {
					notes.deleteTag(tag)
					deletingTag = nil
				}
			}
		} message: {
			Text("Remove \"\(deletingTag ?? "")\" from all notes? This cannot be undone.")
		}
	}

	@ViewBuilder
	private func tagRow(_ tag: String) -> some View {
		HStack {
			if renamingTag == tag {
				TextField("New name", text: $renameText)
					.textFieldStyle(.roundedBorder)
					.onSubmit { commitRename(tag) }
				Button("Save") { commitRename(tag) }
					.buttonStyle(.bordered)
					.controlSize(.small)
					.disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
				Button("Cancel") { renamingTag = nil }
					.buttonStyle(.bordered)
					.controlSize(.small)
			} else if mergingTag == tag {
				Text(tag)
					.font(.body)
				Image(systemName: "arrow.right")
					.foregroundStyle(.secondary)
				Picker("Into", selection: $mergeTarget) {
					Text("Select…").tag(nil as String?)
					ForEach(sortedTags.filter { $0 != tag }, id: \.self) { t in
						Text(t).tag(t as String?)
					}
				}
				.frame(maxWidth: 120)
				Button("Merge") {
					if let target = mergeTarget, target != tag {
						notes.mergeTags(tag, into: target)
						mergingTag = nil
						mergeTarget = nil
					}
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.disabled(mergeTarget == nil || mergeTarget == tag)
				Button("Cancel") { mergingTag = nil; mergeTarget = nil }
					.buttonStyle(.bordered)
					.controlSize(.small)
			} else {
				HStack(spacing: 4) {
					Text(tag)
						.font(.body)
					Text("(\(notes.notesWithTag(tag).count))")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button {
					renameText = tag
					renamingTag = tag
					mergingTag = nil
				} label: {
					Image(systemName: "pencil")
				}
				.buttonStyle(.borderless)
				.accessibilityLabel("Rename tag \(tag)")
				Button {
					mergeTarget = nil
					mergingTag = tag
					renamingTag = nil
				} label: {
					Image(systemName: "arrow.triangle.merge")
				}
				.buttonStyle(.borderless)
				.accessibilityLabel("Merge tag \(tag)")
				Button {
					deletingTag = tag
				} label: {
					Image(systemName: "trash")
						.foregroundStyle(.red)
				}
				.buttonStyle(.borderless)
				.accessibilityLabel("Delete tag \(tag)")
			}
		}
		.padding(.vertical, 2)
	}

	private func commitRename(_ oldTag: String) {
		let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !newName.isEmpty else { return }
		notes.renameTag(oldTag, to: newName)
		renamingTag = nil
	}
}
