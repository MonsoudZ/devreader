import Foundation

/// Schema versioning and migration support for library data
struct LibraryEnvelope: Codable {
    let schemaVersion: String
    let createdDate: Date
    let lastModified: Date
    let items: [LibraryItem]
    
    init(items: [LibraryItem]) {
        self.schemaVersion = "2.0"
        self.createdDate = Date()
        self.lastModified = Date()
        self.items = items
    }
    
    init(schemaVersion: String, createdDate: Date, lastModified: Date, items: [LibraryItem]) {
        self.schemaVersion = schemaVersion
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.items = items
    }
}



// MARK: - Schema Migration

struct LibraryMigration {
    static func migrateLibraryData(_ data: Data) throws -> LibraryEnvelope {
        // Try to decode as new format first
        if let envelope = try? JSONDecoder().decode(LibraryEnvelope.self, from: data) {
            return envelope
        }
        
        // Try to decode as old format and migrate
        if let oldItems = try? JSONDecoder().decode([OldLibraryItem].self, from: data) {
            let migratedItems = oldItems.map { LibraryItem.migrateFromOldFormat(oldItem: $0) }
            return LibraryEnvelope(items: migratedItems)
        }
        
        // Try to decode as raw array of new items
        if let items = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            return LibraryEnvelope(items: items)
        }
        
        throw MigrationError.unsupportedFormat
    }
}

enum MigrationError: LocalizedError {
    case unsupportedFormat
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported library data format"
        case .corruptedData:
            return "Library data is corrupted and cannot be migrated"
        }
    }
}
