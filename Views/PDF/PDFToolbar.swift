import SwiftUI
import PDFKit

struct PDFToolbar: View {
	@ObservedObject var pdf: PDFController
	@State private var pageInput: String = ""
	@FocusState private var isPageFieldFocused: Bool

	var body: some View {
		HStack(spacing: 12) {
			// Page navigation
			pageNavigation

			Divider().frame(height: 18)

			// Display mode picker
			displayModePicker

			Divider().frame(height: 18)

			// Zoom controls
			zoomControls
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(.regularMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 8))
		.shadow(color: .black.opacity(0.15), radius: 4, y: -2)
		.onChange(of: pdf.currentPageIndex) { _, newValue in
			if !isPageFieldFocused {
				pageInput = "\(newValue + 1)"
			}
		}
		.onAppear {
			pageInput = "\(pdf.currentPageIndex + 1)"
		}
	}

	// MARK: - Page Navigation

	private var pageNavigation: some View {
		HStack(spacing: 4) {
			Button {
				pdf.goToFirstPage()
			} label: {
				Image(systemName: "backward.end.fill")
			}
			.buttonStyle(.borderless)
			.disabled(pdf.currentPageIndex <= 0)
			.help("First Page")
			.accessibilityLabel("First page")

			Button {
				pdf.goToPreviousPage()
			} label: {
				Image(systemName: "chevron.left")
			}
			.buttonStyle(.borderless)
			.disabled(pdf.currentPageIndex <= 0)
			.help("Previous Page")
			.accessibilityLabel("Previous page")

			TextField("", text: $pageInput)
				.textFieldStyle(.roundedBorder)
				.frame(width: 44)
				.multilineTextAlignment(.center)
				.focused($isPageFieldFocused)
				.onSubmit { goToInputPage() }
				.accessibilityLabel("Page number")

			Text("/ \(pdf.document?.pageCount ?? 0)")
				.font(.caption)
				.foregroundColor(.secondary)
				.monospacedDigit()

			Button {
				pdf.goToNextPage()
			} label: {
				Image(systemName: "chevron.right")
			}
			.buttonStyle(.borderless)
			.disabled(pdf.document == nil || pdf.currentPageIndex >= (pdf.document?.pageCount ?? 1) - 1)
			.help("Next Page")
			.accessibilityLabel("Next page")

			Button {
				pdf.goToLastPage()
			} label: {
				Image(systemName: "forward.end.fill")
			}
			.buttonStyle(.borderless)
			.disabled(pdf.document == nil || pdf.currentPageIndex >= (pdf.document?.pageCount ?? 1) - 1)
			.help("Last Page")
			.accessibilityLabel("Last page")
		}
	}

	// MARK: - Display Mode

	private var displayModePicker: some View {
		HStack(spacing: 4) {
			Button {
				pdf.setDisplayMode(.singlePage)
			} label: {
				Image(systemName: "doc")
			}
			.buttonStyle(.borderless)
			.foregroundColor(pdf.displayMode == .singlePage ? .accentColor : .secondary)
			.help("Single Page")
			.accessibilityLabel("Single page mode")

			Button {
				pdf.setDisplayMode(.singlePageContinuous)
			} label: {
				Image(systemName: "doc.text")
			}
			.buttonStyle(.borderless)
			.foregroundColor(pdf.displayMode == .singlePageContinuous ? .accentColor : .secondary)
			.help("Continuous Scroll")
			.accessibilityLabel("Continuous scroll mode")

			Button {
				pdf.setDisplayMode(.twoUpContinuous)
			} label: {
				Image(systemName: "book")
			}
			.buttonStyle(.borderless)
			.foregroundColor(pdf.displayMode == .twoUpContinuous ? .accentColor : .secondary)
			.help("Two-Page Spread")
			.accessibilityLabel("Two page spread mode")
		}
	}

	// MARK: - Zoom

	private var zoomControls: some View {
		HStack(spacing: 4) {
			Button {
				pdf.zoomOut()
			} label: {
				Image(systemName: "minus.magnifyingglass")
			}
			.buttonStyle(.borderless)
			.help("Zoom Out")
			.accessibilityLabel("Zoom out")

			Text("\(Int(pdf.scaleFactor * 100))%")
				.font(.caption)
				.monospacedDigit()
				.frame(width: 40)
				.foregroundColor(.secondary)

			Button {
				pdf.zoomIn()
			} label: {
				Image(systemName: "plus.magnifyingglass")
			}
			.buttonStyle(.borderless)
			.help("Zoom In")
			.accessibilityLabel("Zoom in")

			Button {
				pdf.zoomToFit()
			} label: {
				Image(systemName: "arrow.up.left.and.arrow.down.right")
			}
			.buttonStyle(.borderless)
			.help("Fit to Window")
			.accessibilityLabel("Fit to window")
		}
	}

	// MARK: - Helpers

	private func goToInputPage() {
		guard let pageNum = Int(pageInput), let doc = pdf.document else {
			pageInput = "\(pdf.currentPageIndex + 1)"
			return
		}
		let clamped = max(1, min(pageNum, doc.pageCount))
		pdf.goToPage(clamped - 1)
		pageInput = "\(clamped)"
		isPageFieldFocused = false
	}
}
