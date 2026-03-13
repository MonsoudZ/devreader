import SwiftUI
@preconcurrency import PDFKit
import AppKit
import Combine
import UniformTypeIdentifiers

struct PDFFormView: View {
	@ObservedObject var pdf: PDFController
	@State private var formFields: [FormFieldInfo] = []
	@State private var showingSavePanel = false

	struct FormFieldInfo: Identifiable {
		let id = UUID()
		let pageIndex: Int
		let fieldName: String
		let fieldType: PDFAnnotationWidgetSubtype
		let annotation: PDFAnnotation
	}

	var body: some View {
		VStack(spacing: 0) {
			// Header
			HStack {
				Text("Form Fields").font(DS.Typography.heading)
				Spacer()
				Text("\(formFields.count) fields")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.secondary)
			}
			.padding(DS.Spacing.sm)

			Divider()

			if formFields.isEmpty {
				emptyState
			} else {
				formFieldList
			}

			// Bottom action buttons
			if !formFields.isEmpty {
				Divider()
				actionButtons
			}
		}
		.onAppear { scanFormFields() }
		.onChange(of: pdf.document) { _, _ in scanFormFields() }
		.accessibilityLabel("Form fields panel")
	}

	// MARK: - Empty State

	@ViewBuilder
	private var emptyState: some View {
		VStack {
			Spacer()
			if pdf.document != nil {
				Image(systemName: "doc.text.magnifyingglass")
					.font(.system(size: DS.Layout.iconXl))
					.foregroundStyle(DS.Colors.secondary)
				Text("No form fields found")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.secondary)
				Text("This PDF does not contain fillable form fields.")
					.font(DS.Typography.caption2)
					.foregroundStyle(DS.Colors.tertiary)
					.padding(.top, DS.Spacing.xxs)
			} else {
				Text("No PDF open")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.secondary)
			}
			Spacer()
		}
	}

	// MARK: - Form Field List

	@ViewBuilder
	private var formFieldList: some View {
		List {
			ForEach(formFields) { field in
				FormFieldRow(field: field, navigateAction: {
					navigateToField(field)
				})
			}
		}
	}

	// MARK: - Action Buttons

	@ViewBuilder
	private var actionButtons: some View {
		VStack(spacing: DS.Spacing.md) {
			Button {
				saveFilledPDF()
			} label: {
				Label("Save Filled PDF\u{2026}", systemImage: "square.and.arrow.down")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(DSPrimaryButtonStyle())

			Button {
				clearAllFields()
			} label: {
				Label("Clear All Fields", systemImage: "trash")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(DSDestructiveButtonStyle())
		}
		.padding(DS.Spacing.sm)
	}

	// MARK: - Scanning

	private func scanFormFields() {
		guard let doc = pdf.document else {
			formFields = []
			return
		}
		var fields: [FormFieldInfo] = []
		for i in 0..<doc.pageCount {
			guard let page = doc.page(at: i) else { continue }
			for annotation in page.annotations {
				guard annotation.type == "Widget" else { continue }
				let name = annotation.fieldName ?? ""
				fields.append(FormFieldInfo(
					pageIndex: i,
					fieldName: name,
					fieldType: annotation.widgetFieldType,
					annotation: annotation
				))
			}
		}
		formFields = fields
	}

	// MARK: - Navigation

	private func navigateToField(_ field: FormFieldInfo) {
		pdf.goToPage(field.pageIndex)
		if let pdfView = pdf.selectionBridge.pdfView,
		   let doc = pdf.document,
		   let page = doc.page(at: field.pageIndex) {
			let bounds = field.annotation.bounds
			let dest = PDFDestination(page: page, at: CGPoint(
				x: bounds.midX,
				y: bounds.midY
			))
			pdfView.go(to: dest)
		}
	}

	// MARK: - Save Filled PDF

	private func saveFilledPDF() {
		guard let doc = pdf.document else { return }
		let panel = NSSavePanel()
		panel.allowedContentTypes = [.pdf]
		let baseName = pdf.currentPDFURL?.deletingPathExtension().lastPathComponent ?? "FilledForm"
		panel.nameFieldStringValue = "\(baseName)-filled.pdf"

		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			if doc.write(to: url) {
				pdf.toastRequestPublisher.send(
					ToastMessage(message: "Filled PDF saved", type: .success)
				)
			} else {
				pdf.toastRequestPublisher.send(
					ToastMessage(message: "Failed to save filled PDF", type: .error)
				)
			}
		}
	}

	// MARK: - Clear All Fields

	private func clearAllFields() {
		for field in formFields {
			let annotation = field.annotation
			switch field.fieldType {
			case .text, .choice:
				annotation.widgetStringValue = ""
			case .button:
				annotation.buttonWidgetState = .offState
			default:
				break
			}
		}
		// Force PDFView to redraw so cleared values are visible
		pdf.selectionBridge.pdfView?.setNeedsDisplay(
			pdf.selectionBridge.pdfView?.bounds ?? .zero
		)
		// Persist cleared state
		pdf.saveFormData()
		pdf.toastRequestPublisher.send(
			ToastMessage(message: "All form fields cleared", type: .success)
		)
		// Re-scan to refresh bindings
		scanFormFields()
	}
}

// MARK: - Form Field Row (inline editing)

private struct FormFieldRow: View {
	let field: PDFFormView.FormFieldInfo
	let navigateAction: () -> Void

	@State private var textValue: String = ""
	@State private var isChecked: Bool = false
	@State private var selectedChoice: String = ""

	var body: some View {
		VStack(alignment: .leading, spacing: DS.Spacing.xs) {
			// Field header with name + page navigation
			HStack {
				Image(systemName: iconForFieldType(field.fieldType))
					.foregroundStyle(DS.Colors.secondary)
					.frame(width: 16)
				Text(field.fieldName.isEmpty ? "Unnamed Field" : field.fieldName)
					.font(DS.Typography.caption)
					.lineLimit(1)
				Spacer()
				Button {
					navigateAction()
				} label: {
					HStack(spacing: DS.Spacing.xxs) {
						Text("Page \(field.pageIndex + 1)")
							.font(DS.Typography.caption2)
						Image(systemName: "chevron.right")
							.font(.system(size: 9, weight: .semibold))
					}
					.foregroundStyle(DS.Colors.accent)
				}
				.buttonStyle(DSToolbarButtonStyle())
				.help("Navigate to this field in the PDF")
			}

			// Inline editor based on field type
			fieldEditor
		}
		.padding(.vertical, DS.Spacing.xxs)
		.onAppear { loadCurrentValue() }
	}

	@ViewBuilder
	private var fieldEditor: some View {
		switch field.fieldType {
		case .text:
			TextField("Enter value", text: $textValue)
				.textFieldStyle(.roundedBorder)
				.font(DS.Typography.caption)
				.onChange(of: textValue) { _, newValue in
					field.annotation.widgetStringValue = newValue
				}

		case .button:
			Toggle(isOn: $isChecked) {
				Text("Checked")
					.font(DS.Typography.caption2)
					.foregroundStyle(DS.Colors.secondary)
			}
			.toggleStyle(.checkbox)
			.onChange(of: isChecked) { _, newValue in
				field.annotation.buttonWidgetState = newValue ? .onState : .offState
			}

		case .choice:
			let choices = field.annotation.choices ?? []
			if choices.isEmpty {
				TextField("Enter value", text: $textValue)
					.textFieldStyle(.roundedBorder)
					.font(DS.Typography.caption)
					.onChange(of: textValue) { _, newValue in
						field.annotation.widgetStringValue = newValue
					}
			} else {
				Picker("", selection: $selectedChoice) {
					Text("-- Select --").tag("")
					ForEach(choices, id: \.self) { choice in
						Text(choice).tag(choice)
					}
				}
				.pickerStyle(.menu)
				.font(DS.Typography.caption)
				.onChange(of: selectedChoice) { _, newValue in
					field.annotation.widgetStringValue = newValue
				}
			}

		case .signature:
			Text("Use Add Signature (⇧⌘S) to sign")
				.font(DS.Typography.caption2)
				.foregroundStyle(DS.Colors.tertiary)
				.italic()

		default:
			Text("Unsupported field type")
				.font(DS.Typography.caption2)
				.foregroundStyle(DS.Colors.tertiary)
		}
	}

	private func loadCurrentValue() {
		let annotation = field.annotation
		switch field.fieldType {
		case .text:
			textValue = annotation.widgetStringValue ?? ""
		case .button:
			isChecked = annotation.buttonWidgetState == .onState
		case .choice:
			let current = annotation.widgetStringValue ?? ""
			let choices = annotation.choices ?? []
			if choices.isEmpty {
				textValue = current
			} else {
				selectedChoice = choices.contains(current) ? current : ""
			}
		default:
			break
		}
	}

	private func iconForFieldType(_ type: PDFAnnotationWidgetSubtype) -> String {
		switch type {
		case .text: return "character.cursor.ibeam"
		case .button: return "checkmark.square"
		case .choice: return "list.bullet"
		case .signature: return "signature"
		default: return "square"
		}
	}
}
