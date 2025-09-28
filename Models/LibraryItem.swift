//
//  LibraryItem.swift
//  DevReader
//
//  Created on 2024
//

import Foundation

/// Enhanced LibraryItem with stable identity and security-scoped bookmarks
struct LibraryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let securityScopedBookmark: Data?
    let title: String
    let author: String?
    let pageCount: Int
    let fileSize: Int64
    let addedDate: Date
    let lastOpened: Date?
    let tags: [String]
    let isPinned: Bool
    let thumbnailData: Data?
    
    // Computed properties for backward compatibility
    var displayName: String {
        return title.isEmpty ? url.lastPathComponent : title
    }
    
    var fileExtension: String {
        return url.pathExtension.lowercased()
    }
    
    var isPDF: Bool {
        return fileExtension == "pdf"
    }
    
    // Backward compatibility
    var addedAt: Date {
        return addedDate
    }
    
    init(url: URL, securityScopedBookmark: Data? = nil, title: String = "", author: String? = nil, pageCount: Int = 0, fileSize: Int64 = 0, addedDate: Date = Date(), lastOpened: Date? = nil, tags: [String] = [], isPinned: Bool = false, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.url = url
        self.securityScopedBookmark = securityScopedBookmark
        self.title = title.isEmpty ? url.lastPathComponent : title
        self.author = author
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.addedDate = addedDate
        self.lastOpened = lastOpened
        self.tags = tags
        self.isPinned = isPinned
        self.thumbnailData = thumbnailData
    }
    
    // MARK: - Security-Scoped Bookmark Support
    
    /// Create a security-scoped bookmark for the URL
    func createSecurityScopedBookmark() -> Data? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            return nil
        }
    }
    
    /// Resolve URL from security-scoped bookmark
    func resolveURLFromBookmark() -> URL? {
        guard let bookmarkData = securityScopedBookmark else { return url }
        
        do {
            var isStale = false
            let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Bookmark is stale, return original URL
                return url
            }
            
            return resolvedURL
        } catch {
            // Bookmark resolution failed, return original URL
            return url
        }
    }
    
    // MARK: - Duplicate Detection
    
    /// Check if this item is a duplicate of another item
    func isDuplicate(of other: LibraryItem) -> Bool {
        // Check by URL first (exact match)
        if url == other.url {
            return true
        }
        
        // Check by security-scoped bookmark if available
        if let bookmark1 = securityScopedBookmark,
           let bookmark2 = other.securityScopedBookmark,
           bookmark1 == bookmark2 {
            return true
        }
        
        // Check by file attributes (size, modification date)
        let attributes1 = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let attributes2 = (try? FileManager.default.attributesOfItem(atPath: other.url.path)) ?? [:]
        
        let size1 = attributes1[.size] as? Int64 ?? 0
        let size2 = attributes2[.size] as? Int64 ?? 0
        let modDate1 = attributes1[.modificationDate] as? Date
        let modDate2 = attributes2[.modificationDate] as? Date
        
        // Same file if size and modification date match
        if size1 == size2 && size1 > 0,
           let date1 = modDate1, let date2 = modDate2,
           abs(date1.timeIntervalSince(date2)) < 1.0 {
            return true
        }
        
        return false
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Migration Support
    
    /// Migrate from old LibraryItem format
    static func migrateFromOldFormat(oldItem: OldLibraryItem) -> LibraryItem {
        return LibraryItem(
            url: oldItem.url,
            title: oldItem.title,
            author: oldItem.author,
            pageCount: oldItem.pageCount,
            fileSize: oldItem.fileSize,
            addedDate: oldItem.addedDate,
            lastOpened: oldItem.lastOpened,
            tags: oldItem.tags,
            isPinned: oldItem.isPinned,
            thumbnailData: oldItem.thumbnailData
        )
    }
}

// MARK: - Legacy Support

/// Old LibraryItem format for migration
struct OldLibraryItem: Codable {
    let url: URL
    let title: String
    let author: String?
    let pageCount: Int
    let fileSize: Int64
    let addedDate: Date
    let lastOpened: Date?
    let tags: [String]
    let isPinned: Bool
    let thumbnailData: Data?
}
