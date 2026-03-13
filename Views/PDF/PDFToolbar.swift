import SwiftUI
import PDFKit

struct PDFToolbar: View {
	@ObservedObject var pdf: PDFController
	@State private var pageInput: String = ""
	@FocusState private var isPageFieldFocused: Bool

	var body: some View {
		ViewThatFits(in: .horizontal) {
			// Full toolbar
			HStack(spacing: DS.Spacing.md) {
				pageNavigation
				Divider().frame(height: 18)
				displayModePicker
				Divider().frame(height: 18)
				rotationControls
				Divider().frame(height: 18)
				zoomControls
			}

			// Compact: collapse display mode + rotation into a menu
			HStack(spacing: DS.Spacing.md) {
				pageNavigation
				Divider().frame(height: 18)
				zoomControls
				Divider().frame(height: 18)
				compactOverflowMenu
			}

			// Minimal: page nav + overflow only
			HStack(spacing: DS.Spacing.sm) {
				compactPageNavigation
				Divider().frame(height: 18)
				compactOverflowMenu
			}
		}
		.floatingToolbarStyle()
		.onChange(of: pdf.currentPageIndex) { _, newValue in
			if !isPageFieldFocused {
				pageInput = "\(newValue + 1)"
			}
		}
		.onChange(of: isPageFieldFocused) { _, focused in
			if !focused {
				// Sync display when user leaves the field (page may have changed while editing)
				pageInput = "\(pdf.currentPageIndex + 1)"
			}
		}
		.onAppear {
			pageInput = "\(pdf.currentPageIndex + 1)"
		}
	}

	// MARK: - Page Navigation

	private var pageNavigation: some View {
		HStack(spacing: DS.Spacing.xs) {
			Button { pdf.goToPreviousPage() } label: {
				Image(systemName: "chevron.left")
			}
			.buttonStyle(DSToolbarButtonStyle())
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
				.font(DS.Typography.caption)
				.foregroundStyle(DS.Colors.secondary)
				.monospacedDigit()

			Button { pdf.goToNextPage() } label: {
				Image(systemName: "chevron.right")
			}
			.buttonStyle(DSToolbarButtonStyle())
			.disabled(pdf.document == nil || pdf.currentPageIndex >= (pdf.document?.pageCount ?? 1) - 1)
			.help("Next Page")
			.accessibilityLabel("Next page")
		}
	}

	// MARK: - Display Mode

	private var displayModePicker: some View {
		ControlGroup {
			Button {
				pdf.setDisplayMode(.singlePage)
			} label: {
				Label("Single Page", systemImage: "doc")
			}
			.help("Single Page")

			Button {
				pdf.setDisplayMode(.singlePageContinuous)
			} label: {
				Label("Continuous", systemImage: "doc.text")
			}
			.help("Continuous Scroll")

			Button {
				pdf.setDisplayMode(.twoUpContinuous)
			} label: {
				Label("Two-Page", systemImage: "book")
			}
			.help("Two-Page Spread")
		}
		.controlGroupStyle(.automatic)
	}

	// MARK: - Zoom

	private var zoomControls: some View {
		HStack(spacing: DS.Spacing.xs) {
			ControlGroup {
				Button { pdf.zoomOut() } label: {
					Label("Zoom Out", systemImage: "minus.magnifyingglass")
				}
				.help("Zoom Out")

				Button { pdf.zoomIn() } label: {
					Label("Zoom In", systemImage: "plus.magnifyingglass")
				}
				.help("Zoom In")
			}

			Text("\(Int(pdf.scaleFactor * 100))%")
				.font(DS.Typography.caption)
				.monospacedDigit()
				.frame(width: 40)
				.foregroundStyle(DS.Colors.secondary)

			Button {
				pdf.zoomToFit()
			} label: {
				Image(systemName: "arrow.up.left.and.arrow.down.right")
			}
			.buttonStyle(DSToolbarButtonStyle())
			.help("Fit to Window")
			.accessibilityLabel("Fit to window")
		}
	}

	// MARK: - Rotation

	private var rotationControls: some View {
		ControlGroup {
			Button {
				pdf.rotateCurrentPageLeft()
			} label: {
				Label("Rotate Left", systemImage: "rotate.left")
			}
			.help("Rotate Left")

			Button {
				pdf.rotateCurrentPageRight()
			} label: {
				Label("Rotate Right", systemImage: "rotate.right")
			}
			.help("Rotate Right")
		}
		.disabled(pdf.document == nil)
	}

	// MARK: - Compact Variants

	private var compactPageNavigation: some View {
		HStack(spacing: DS.Spacing.xs) {
			Button { pdf.goToPreviousPage() } label: { Image(systemName: "chevron.left") }
				.buttonStyle(DSToolbarButtonStyle())
				.disabled(pdf.currentPageIndex <= 0)
				.accessibilityLabel("Previous page")

			Text("\(pdf.currentPageIndex + 1)/\(pdf.document?.pageCount ?? 0)")
				.font(DS.Typography.caption)
				.monospacedDigit()
				.foregroundStyle(DS.Colors.secondary)

			Button { pdf.goToNextPage() } label: { Image(systemName: "chevron.right") }
				.buttonStyle(DSToolbarButtonStyle())
				.disabled(pdf.document == nil || pdf.currentPageIndex >= (pdf.document?.pageCount ?? 1) - 1)
				.accessibilityLabel("Next page")
		}
	}

	private var compactOverflowMenu: some View {
		Menu {
			Section("Display Mode") {
				Button { pdf.setDisplayMode(.singlePage) } label: {
					Label("Single Page", systemImage: "doc")
				}
				Button { pdf.setDisplayMode(.singlePageContinuous) } label: {
					Label("Continuous", systemImage: "doc.text")
				}
				Button { pdf.setDisplayMode(.twoUpContinuous) } label: {
					Label("Two-Page", systemImage: "book")
				}
			}
			Section("Rotate") {
				Button { pdf.rotateCurrentPageLeft() } label: {
					Label("Rotate Left", systemImage: "rotate.left")
				}
				.disabled(pdf.document == nil)
				Button { pdf.rotateCurrentPageRight() } label: {
					Label("Rotate Right", systemImage: "rotate.right")
				}
				.disabled(pdf.document == nil)
			}
			Section("Zoom") {
				Button { pdf.zoomOut() } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
				Button { pdf.zoomIn() } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
				Button { pdf.zoomToFit() } label: { Label("Fit to Window", systemImage: "arrow.up.left.and.arrow.down.right") }
			}
		} label: {
			Image(systemName: "ellipsis.circle")
		}
		.menuStyle(.borderlessButton)
		.accessibilityLabel("More controls")
	}

	// MARK: - Helpers

	private func goToInputPage() {
		guard let pageNum = Int(pageInput), let doc = pdf.document else {
			pageInput = "\(pdf.currentPageIndex + 1)"
			isPageFieldFocused = false
			return
		}
		let clamped = max(1, min(pageNum, doc.pageCount))
		pdf.goToPage(clamped - 1)
		pageInput = "\(clamped)"
		isPageFieldFocused = false
	}
}
