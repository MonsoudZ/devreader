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
}
