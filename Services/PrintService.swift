import AppKit

/// Provides standard macOS printing for text content (notes, code, etc.).
enum PrintService {

	/// Prints plain text content with a title header.
	static func printText(_ text: String, title: String = "DevReader") {
		let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
		printInfo.topMargin = 36
		printInfo.bottomMargin = 36
		printInfo.leftMargin = 36
		printInfo.rightMargin = 36

		let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
		textView.isEditable = false
		textView.isSelectable = true

		let attributed = NSMutableAttributedString()

		// Title
		let titleAttrs: [NSAttributedString.Key: Any] = [
			.font: NSFont.boldSystemFont(ofSize: 16),
			.foregroundColor: NSColor.labelColor
		]
		attributed.append(NSAttributedString(string: title + "\n\n", attributes: titleAttrs))

		// Body
		let bodyAttrs: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
			.foregroundColor: NSColor.labelColor
		]
		attributed.append(NSAttributedString(string: text, attributes: bodyAttrs))

		textView.textStorage?.setAttributedString(attributed)

		let op = NSPrintOperation(view: textView, printInfo: printInfo)
		op.showsPrintPanel = true
		op.showsProgressPanel = true
		op.run()
	}

	/// Prints notes as formatted Markdown-style content.
	@MainActor
	static func printNotes(items: [NoteItem], pageNotes: [Int: String], title: String = "DevReader Notes") {
		var content = ""

		// Page notes
		let sortedPageNotes = pageNotes.sorted { $0.key < $1.key }
		if !sortedPageNotes.isEmpty {
			content += "── Page Notes ──\n\n"
			for (page, text) in sortedPageNotes where !text.isEmpty {
				content += "Page \(page + 1):\n\(text)\n\n"
			}
		}

		// Grouped notes
		let groups = Dictionary(grouping: items) { $0.chapter.isEmpty ? "(No Chapter)" : $0.chapter }
		for (chapter, notes) in groups.sorted(by: { $0.key < $1.key }) {
			content += "── \(chapter) ──\n\n"
			for note in notes {
				if !note.title.isEmpty {
					content += "[\(note.title)]\n"
				}
				content += "Page \(note.pageIndex + 1)"
				if !note.tags.isEmpty {
					content += " | Tags: \(note.tags.joined(separator: ", "))"
				}
				content += "\n"
				if !note.text.isEmpty {
					content += note.text + "\n"
				}
				content += "\n"
			}
		}

		if content.isEmpty {
			content = "(No notes to print)"
		}

		printText(content, title: title)
	}

	/// Prints code with language header.
	static func printCode(_ code: String, language: String) {
		let title = "DevReader – \(language) Code"
		printText(code, title: title)
	}
}
