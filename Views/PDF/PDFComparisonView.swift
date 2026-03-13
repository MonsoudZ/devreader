import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Side-by-side PDF comparison view.
/// The left pane shows the currently open document (primary PDFController),
/// the right pane shows a user-selected comparison document (secondary PDFController).
/// Page navigation can optionally be synchronized between the two panels.
struct PDFComparisonView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var syncScrolling = true
    @State private var showFilePicker = false

    private var primary: PDFController { appEnvironment.pdfController }
    private var secondary: PDFController { appEnvironment.secondaryPDFController }

    var body: some View {
        VStack(spacing: 0) {
            comparisonToolbar
            Divider()
            comparisonContent
        }
        .frame(minWidth: 900, minHeight: 600)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onDisappear {
            // Clear the secondary document when the comparison sheet is dismissed
            secondary.document = nil
        }
        .onChange(of: primary.currentPageIndex) { _, newValue in
            guard syncScrolling, secondary.document != nil else { return }
            secondary.goToPage(newValue)
        }
        .onChange(of: secondary.currentPageIndex) { _, newValue in
            guard syncScrolling, primary.document != nil else { return }
            if primary.currentPageIndex != newValue {
                primary.goToPage(newValue)
            }
        }
    }

    // MARK: - Toolbar

    private var comparisonToolbar: some View {
        HStack(spacing: 16) {
            Button {
                if syncScrolling {
                    let targetPage = min(primary.currentPageIndex, secondary.currentPageIndex)
                    let prevPage = max(targetPage - 1, 0)
                    primary.goToPage(prevPage)
                } else {
                    primary.goToPreviousPage()
                }
            } label: {
                Label("Previous Page", systemImage: "chevron.left")
            }
            .disabled(primary.document == nil)
            .accessibilityLabel("Previous page")

            Button {
                if syncScrolling {
                    let maxPrimary = primary.document?.pageCount ?? 1
                    let maxSecondary = secondary.document?.pageCount ?? 1
                    let limit = min(maxPrimary, maxSecondary) - 1
                    let targetPage = min(primary.currentPageIndex, secondary.currentPageIndex)
                    let nextPage = min(targetPage + 1, limit)
                    primary.goToPage(nextPage)
                } else {
                    primary.goToNextPage()
                }
            } label: {
                Label("Next Page", systemImage: "chevron.right")
            }
            .disabled(primary.document == nil)
            .accessibilityLabel("Next page")

            Divider()
                .frame(height: 20)

            Toggle(isOn: $syncScrolling) {
                Label("Sync Scrolling", systemImage: "link")
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Synchronize page scrolling")

            Spacer()

            if secondary.document == nil {
                Button("Choose Comparison PDF\u{2026}") {
                    showFilePicker = true
                }
                .accessibilityLabel("Choose comparison PDF")
            } else {
                Button("Change PDF\u{2026}") {
                    showFilePicker = true
                }
                .accessibilityLabel("Change comparison PDF")
            }

            Button("Done") {
                appEnvironment.isShowingComparison = false
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close comparison view")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Content

    private var comparisonContent: some View {
        HStack(spacing: 0) {
            // Left panel — primary document
            pdfPanel(
                controller: primary,
                label: primary.currentPDFURL?.lastPathComponent ?? "Current Document",
                isEmpty: primary.document == nil,
                emptyMessage: "No PDF open"
            )

            Divider()

            // Right panel — comparison document
            pdfPanel(
                controller: secondary,
                label: secondary.currentPDFURL?.lastPathComponent ?? "Comparison Document",
                isEmpty: secondary.document == nil,
                emptyMessage: "Select a PDF to compare"
            )
        }
    }

    private func pdfPanel(
        controller: PDFController,
        label: String,
        isEmpty: Bool,
        emptyMessage: String
    ) -> some View {
        VStack(spacing: 0) {
            // Header with filename and page indicator
            HStack {
                Text(label)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if let doc = controller.document {
                    Text("Page \(controller.currentPageIndex + 1) of \(doc.pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            if isEmpty {
                emptyPlaceholder(message: emptyMessage)
            } else {
                PDFViewRepresentable(pdf: controller)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyPlaceholder(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            secondary.load(url: url)
        case .failure(let error):
            appEnvironment.enhancedToastCenter.showError(
                "Failed to Open PDF",
                error.localizedDescription
            )
        }
    }
}
