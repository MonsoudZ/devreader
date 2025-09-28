//
//  NoteItem.swift
//  DevReader
//
//  Created on 2024
//

import Foundation

struct NoteItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var text: String
    var pageIndex: Int
    var chapter: String
    var date: Date
    var tags: [String]
    
    init(title: String = "", text: String, pageIndex: Int, chapter: String, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.text = text
        self.pageIndex = pageIndex
        self.chapter = chapter
        self.date = Date()
        self.tags = tags
    }
    
    // Computed property for display title
    var displayTitle: String {
        return title.isEmpty ? "Note on page \(pageIndex + 1)" : title
    }
}
