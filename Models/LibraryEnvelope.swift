import Foundation
import os.log

/// Schema versioning and migration support for library data
nonisolated struct LibraryEnvelope: Codable, Sendable {
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

nonisolated struct LibraryMigration {
    private static let logger = AppLog.persistence

    static func migrateLibraryData(_ data: Data) throws -> LibraryEnvelope {
        // Try to decode as new format first
        do {
            return try JSONDecoder().decode(LibraryEnvelope.self, from: data)
        } catch {
            os_log("Envelope decode failed, trying legacy formats: %{public}@", log: logger, type: .debug, error.localizedDescription)
        }

        // Try to decode as old format and migrate
        do {
            let oldItems = try JSONDecoder().decode([OldLibraryItem].self, from: data)
            let migratedItems = oldItems.map { LibraryItem.migrateFromOldFormat(oldItem: $0) }
            os_log("Migrated %d items from OldLibraryItem format", log: logger, type: .info, migratedItems.count)
            return LibraryEnvelope(items: migratedItems)
        } catch {
            os_log("OldLibraryItem decode failed: %{public}@", log: logger, type: .debug, error.localizedDescription)
        }

        // Try to decode as raw array of new items
        do {
            let items = try JSONDecoder().decode([LibraryItem].self, from: data)
            os_log("Decoded %d items from raw LibraryItem array", log: logger, type: .info, items.count)
            return LibraryEnvelope(items: items)
        } catch {
            os_log("LibraryItem array decode failed: %{public}@", log: logger, type: .error, error.localizedDescription)
        }

        throw MigrationError.unsupportedFormat
    }
}

nonisolated enum MigrationError: LocalizedError {
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
