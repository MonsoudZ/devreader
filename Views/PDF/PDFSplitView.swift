import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFSplitView: View {
	@ObservedObject var primaryPDF: PDFController
	@ObservedObject var secondaryPDF: PDFController
	@Binding var isSplitActive: Bool

	var body: some View {
		HSplitView {
			PDFViewRepresentable(pdf: primaryPDF)
				.frame(maxWidth: .infinity, maxHeight: .infinity)

			if isSplitActive {
				Divider()
				VStack(spacing: 0) {
					splitToolbar
					PDFViewRepresentable(pdf: secondaryPDF)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
		}
	}

	private var splitToolbar: some View {
		HStack(spacing: 8) {
			if let doc = secondaryPDF.document {
				Text(doc.documentURL?.deletingPathExtension().lastPathComponent ?? "PDF")
					.font(.caption)
					.lineLimit(1)
				Text("Page \(secondaryPDF.currentPageIndex + 1)/\(doc.pageCount)")
					.font(.caption)
					.foregroundStyle(.secondary)
					.monospacedDigit()
			} else {
				Text("No PDF")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()

			Button {
				openInSplit()
			} label: {
				Image(systemName: "folder")
			}
			.buttonStyle(.borderless)
			.help("Open PDF in split")
			.accessibilityLabel("Open PDF in split view")

			Button {
				if primaryPDF.currentPDFURL != nil {
					if let url = primaryPDF.currentPDFURL {
						secondaryPDF.load(url: url)
					}
				}
			} label: {
				Image(systemName: "doc.on.doc")
			}
			.buttonStyle(.borderless)
			.help("Mirror current PDF")
			.accessibilityLabel("Open same PDF in split")

			Button {
				isSplitActive = false
				secondaryPDF.clearSession()
			} label: {
				Image(systemName: "xmark")
			}
			.buttonStyle(.borderless)
			.help("Close split view")
			.accessibilityLabel("Close split view")
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 4)
		.background(.regularMaterial)
	}

	private func openInSplit() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.pdf]
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			DispatchQueue.main.async {
				secondaryPDF.load(url: url)
			}
		}
	}
}
