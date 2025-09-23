//
//  LibraryItem.swift
//  DevReader
//
//  Created on 2024
//

import Foundation

struct LibraryItem: Identifiable, Codable, Hashable {
    let id: UUID
    var url: URL
    var title: String
    var addedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.addedAt = Date()
    }
}
