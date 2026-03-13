//
//  AnnotationExportService.swift
//  DevReader
//
//  Created on 2024
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

/// Exports PDF annotations, notes, and bookmarks as a structured Markdown file.
@MainActor
enum AnnotationExportService {

    // MARK: - Public API

    /// Exports annotations, notes, and bookmarks for a given PDF as Markdown via NSSavePanel.
    static func exportMarkdown(
        for url: URL,
        title: String,
        annotations: [PDFAnnotationData],
        notes: [NoteItem],
        bookmarks: Set<Int>
    ) {
        let markdown = generateMarkdown(
            title: title,
            annotations: annotations,
            notes: notes,
            bookmarks: bookmarks
        )
        presentSavePanel(suggestedName: title, markdown: markdown)
    }

    /// Convenience method that extracts all data from a PDFController and its associated NotesStore.
    static func exportMarkdown(from controller: PDFController, notesStore: NotesStore) {
        guard let url = controller.currentPDFURL else {
            controller.toastRequestPublisher.send(
                ToastMessage(message: "No PDF open to export", type: .warning)
            )
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let annotations = controller.annotationManager.currentAnnotations()
        let notes = notesStore.items
        let bookmarks = controller.bookmarkManager.bookmarks

        let markdown = generateMarkdown(
            title: title,
            annotations: annotations,
            notes: notes,
            bookmarks: bookmarks
        )
        presentSavePanel(suggestedName: title, markdown: markdown)
    }

    // MARK: - Markdown Generation (nonisolated)

    /// Pure function that builds the Markdown string. Safe to call from any isolation context.
    nonisolated static func generateMarkdown(
        title: String,
        annotations: [PDFAnnotationData],
        notes: [NoteItem],
        bookmarks: Set<Int>
    ) -> String {
        var lines: [String] = []

        // Header
        lines.append("# \(title)")
        let dateString = Self.exportDateFormatter.string(from: Date())
        lines.append("_Exported from DevReader on \(dateString)_")
        lines.append("")

        // Highlights section
        let highlights = annotations.filter { $0.type == .highlight }
        let underlines = annotations.filter { $0.type == .underline }
        let strikethroughs = annotations.filter { $0.type == .strikethrough }

        if !highlights.isEmpty {
            lines.append("## Highlights")
            lines.append("")
            for annotation in highlights.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                let text = annotation.text ?? "(no text captured)"
                lines.append("- **Page \(annotation.pageIndex + 1)**: \"\(text)\"")
            }
            lines.append("")
        }

        if !underlines.isEmpty {
            lines.append("## Underlines")
            lines.append("")
            for annotation in underlines.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                let text = annotation.text ?? "(no text captured)"
                lines.append("- **Page \(annotation.pageIndex + 1)**: \"\(text)\"")
            }
            lines.append("")
        }

        if !strikethroughs.isEmpty {
            lines.append("## Strikethroughs")
            lines.append("")
            for annotation in strikethroughs.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                let text = annotation.text ?? "(no text captured)"
                lines.append("- **Page \(annotation.pageIndex + 1)**: \"\(text)\"")
            }
            lines.append("")
        }

        // Notes section
        if !notes.isEmpty {
            lines.append("## Notes")
            lines.append("")
            let grouped = Dictionary(grouping: notes, by: { $0.chapter })
            let sortedChapters = grouped.keys.sorted()
            for chapter in sortedChapters {
                guard let chapterNotes = grouped[chapter] else { continue }
                lines.append("### \(chapter)")
                lines.append("")
                for note in chapterNotes.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                    let titlePart = note.title.isEmpty ? "" : "\(note.title) — "
                    let textOneLine = note.text
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    lines.append("- **Page \(note.pageIndex + 1)**: \(titlePart)\(textOneLine)")
                }
                lines.append("")
            }
        }

        // Bookmarks section
        if !bookmarks.isEmpty {
            lines.append("## Bookmarks")
            lines.append("")
            let sorted = bookmarks.sorted()
            let pageList = sorted.map { "Page \($0 + 1)" }.joined(separator: ", ")
            lines.append("- \(pageList)")
            lines.append("")
        }

        // If nothing was exported, add a note
        if annotations.isEmpty && notes.isEmpty && bookmarks.isEmpty {
            lines.append("_No annotations, notes, or bookmarks found for this document._")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Save Panel

    private static func presentSavePanel(suggestedName: String, markdown: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "\(suggestedName)-notes.md"
        panel.title = "Export Annotations as Markdown"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                logError(AppLog.persistence, "Failed to export Markdown: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private nonisolated static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}
