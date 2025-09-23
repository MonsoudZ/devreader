//
//  NoteItem.swift
//  DevReader
//
//  Created on 2024
//

import Foundation

struct NoteItem: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var pageIndex: Int
    var chapter: String
    var date: Date
    var tags: [String]
    
    init(text: String, pageIndex: Int, chapter: String, tags: [String] = []) {
        self.id = UUID()
        self.text = text
        self.pageIndex = pageIndex
        self.chapter = chapter
        self.date = Date()
        self.tags = tags
    }
}
