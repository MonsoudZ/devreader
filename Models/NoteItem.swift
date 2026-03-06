//
//  NoteItem.swift
//  DevReader
//
//  Created on 2024
//

import Foundation

nonisolated struct NoteItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var text: String
    var pageIndex: Int
    var chapter: String
    var date: Date
    var tags: [String]
    
    init(title: String = "", text: String, pageIndex: Int, chapter: String, tags: [String] = [], date: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.text = text
        self.pageIndex = pageIndex
        self.chapter = chapter
        self.date = date
        self.tags = tags
    }
    
    // Computed property for display title
    var displayTitle: String {
        return title.isEmpty ? "Note on page \(pageIndex + 1)" : title
    }

    // MARK: - Templates

    nonisolated struct Template: Codable, Sendable {
        let name: String
        let icon: String
        let titleTemplate: String
        let textTemplate: String
        let tags: [String]
    }

    static let templates: [Template] = [
        Template(name: "Summary", icon: "doc.text", titleTemplate: "Summary", textTemplate: "Key points:\n- \n\nConclusion:\n", tags: ["summary"]),
        Template(name: "Question", icon: "questionmark.circle", titleTemplate: "Question", textTemplate: "Question:\n\nContext:\n\nPossible answer:\n", tags: ["question"]),
        Template(name: "Definition", icon: "textformat.abc", titleTemplate: "Definition", textTemplate: "Term:\n\nDefinition:\n\nExample:\n", tags: ["definition"]),
        Template(name: "TODO", icon: "checklist", titleTemplate: "TODO", textTemplate: "- [ ] \n- [ ] \n- [ ] \n", tags: ["todo"]),
        Template(name: "Code Note", icon: "chevron.left.forwardslash.chevron.right", titleTemplate: "Code Note", textTemplate: "Language:\n\nCode:\n```\n\n```\n\nExplanation:\n", tags: ["code"]),
    ]

    static func fromTemplate(_ template: Template, pageIndex: Int, chapter: String) -> NoteItem {
        NoteItem(
            title: template.titleTemplate,
            text: template.textTemplate,
            pageIndex: pageIndex,
            chapter: chapter,
            tags: template.tags
        )
    }
}
