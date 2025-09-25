import Foundation
import os.log

/// Enhanced JSON file-based storage system for better performance and reliability
enum JSONStorageService {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "JSONStorage")
    
    // MARK: - Storage Locations
    static var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DevReader", isDirectory: true)
    }
    
    static var dataDirectory: URL {
        appSupportURL.appendingPathComponent("Data", isDirectory: true)
    }
    
    static var backupDirectory: URL {
        appSupportURL.appendingPathComponent("Backups", isDirectory: true)
    }
    
    // MARK: - File Paths
    static func libraryPath() -> URL {
        dataDirectory.appendingPathComponent("library.json")
    }
    
    static func notesPath(for pdfURL: URL) -> URL {
        let hash = String(pdfURL.path.hashValue)
        return dataDirectory.appendingPathComponent("notes_\(hash).json")
    }
    
    static func sessionPath(for pdfURL: URL) -> URL {
        let hash = String(pdfURL.path.hashValue)
        return dataDirectory.appendingPathComponent("session_\(hash).json")
    }
    
    static func bookmarksPath(for pdfURL: URL) -> URL {
        let hash = String(pdfURL.path.hashValue)
        return dataDirectory.appendingPathComponent("bookmarks_\(hash).json")
    }
    
    static func recentsPath() -> URL {
        dataDirectory.appendingPathComponent("recents.json")
    }
    
    static func pinnedPath() -> URL {
        dataDirectory.appendingPathComponent("pinned.json")
    }
    
    // MARK: - Directory Management
    static func ensureDirectories() {
        let directories = [dataDirectory, backupDirectory]
        for dir in directories {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                os_log("Created directory: %{public}@", log: logger, type: .debug, dir.path)
            } catch {
                os_log("Failed to create directory %{public}@: %{public}@", log: logger, type: .error, dir.path, error.localizedDescription)
            }
        }
    }
    
    // MARK: - JSON Operations
    static func save<T: Codable>(_ data: T, to url: URL) throws {
        ensureDirectories()
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: url)
        os_log("Saved data to: %{public}@", log: logger, type: .debug, url.path)
    }
    
    static func load<T: Codable>(_ type: T.Type, from url: URL) throws -> T {
        let jsonData = try Data(contentsOf: url)
        let result = try JSONDecoder().decode(type, from: jsonData)
        os_log("Loaded data from: %{public}@", log: logger, type: .debug, url.path)
        return result
    }
    
    static func loadOptional<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { 
            os_log("File does not exist: %{public}@", log: logger, type: .debug, url.path)
            return nil 
        }
        do {
            return try load(type, from: url)
        } catch {
            os_log("Failed to load data from %{public}@: %{public}@", log: logger, type: .error, url.path, error.localizedDescription)
            return nil
        }
    }
    
    static func delete(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            os_log("Deleted file: %{public}@", log: logger, type: .debug, url.path)
        } catch {
            os_log("Failed to delete file %{public}@: %{public}@", log: logger, type: .error, url.path, error.localizedDescription)
        }
    }
    
    // MARK: - Migration from UserDefaults
    static func migrateFromUserDefaults() {
        os_log("Starting migration from UserDefaults to JSON files", log: logger, type: .info)
        
        ensureDirectories()
        
        // Migrate library
        if let libraryData = UserDefaults.standard.data(forKey: "DevReader.Library.v1"),
           let library = try? JSONDecoder().decode([LibraryItem].self, from: libraryData) {
            do {
                try save(library, to: libraryPath())
                UserDefaults.standard.removeObject(forKey: "DevReader.Library.v1")
                os_log("Migrated library data", log: logger, type: .info)
            } catch {
                os_log("Failed to migrate library data: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        // Migrate recent documents
        if let recentData = UserDefaults.standard.data(forKey: "DevReader.Recents.v1"),
           let recents = try? JSONDecoder().decode([URL].self, from: recentData) {
            do {
                try save(recents, to: recentsPath())
                UserDefaults.standard.removeObject(forKey: "DevReader.Recents.v1")
                os_log("Migrated recent documents", log: logger, type: .info)
            } catch {
                os_log("Failed to migrate recent documents: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        // Migrate pinned documents
        if let pinnedData = UserDefaults.standard.data(forKey: "DevReader.Pinned.v1"),
           let pinned = try? JSONDecoder().decode([URL].self, from: pinnedData) {
            do {
                try save(pinned, to: pinnedPath())
                UserDefaults.standard.removeObject(forKey: "DevReader.Pinned.v1")
                os_log("Migrated pinned documents", log: logger, type: .info)
            } catch {
                os_log("Failed to migrate pinned documents: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        // Migrate per-PDF data
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let pdfHashes = Set(allKeys.compactMap { key in
            if key.hasPrefix("DevReader.Notes.v1.") {
                return String(key.dropFirst("DevReader.Notes.v1.".count))
            }
            return nil
        })
        
        for hash in pdfHashes {
            // Migrate notes
            if let notesData = UserDefaults.standard.data(forKey: "DevReader.Notes.v1.\(hash)"),
               let notes = try? JSONDecoder().decode([NoteItem].self, from: notesData) {
                let notesURL = dataDirectory.appendingPathComponent("notes_\(hash).json")
                do {
                    try save(notes, to: notesURL)
                    UserDefaults.standard.removeObject(forKey: "DevReader.Notes.v1.\(hash)")
                    os_log("Migrated notes for hash: %{public}@", log: logger, type: .info, hash)
                } catch {
                    os_log("Failed to migrate notes for hash %{public}@: %{public}@", log: logger, type: .error, hash, error.localizedDescription)
                }
            }
            
            // Migrate page notes
            if let pageNotesData = UserDefaults.standard.data(forKey: "DevReader.PageNotes.v1.\(hash)"),
               let pageNotes = try? JSONDecoder().decode([Int: String].self, from: pageNotesData) {
                let pageNotesURL = dataDirectory.appendingPathComponent("page_notes_\(hash).json")
                do {
                    try save(pageNotes, to: pageNotesURL)
                    UserDefaults.standard.removeObject(forKey: "DevReader.PageNotes.v1.\(hash)")
                    os_log("Migrated page notes for hash: %{public}@", log: logger, type: .info, hash)
                } catch {
                    os_log("Failed to migrate page notes for hash %{public}@: %{public}@", log: logger, type: .error, hash, error.localizedDescription)
                }
            }
            
            // Migrate tags
            if let tagsData = UserDefaults.standard.data(forKey: "DevReader.Tags.v1.\(hash)"),
               let tags = try? JSONDecoder().decode([String].self, from: tagsData) {
                let tagsURL = dataDirectory.appendingPathComponent("tags_\(hash).json")
                do {
                    try save(tags, to: tagsURL)
                    UserDefaults.standard.removeObject(forKey: "DevReader.Tags.v1.\(hash)")
                    os_log("Migrated tags for hash: %{public}@", log: logger, type: .info, hash)
                } catch {
                    os_log("Failed to migrate tags for hash %{public}@: %{public}@", log: logger, type: .error, hash, error.localizedDescription)
                }
            }
            
            // Migrate sessions
            if let sessionData = UserDefaults.standard.data(forKey: "DevReader.Session.v1.\(hash)") {
                let sessionURL = dataDirectory.appendingPathComponent("session_\(hash).json")
                do {
                    try sessionData.write(to: sessionURL)
                    UserDefaults.standard.removeObject(forKey: "DevReader.Session.v1.\(hash)")
                    os_log("Migrated session for hash: %{public}@", log: logger, type: .info, hash)
                } catch {
                    os_log("Failed to migrate session for hash %{public}@: %{public}@", log: logger, type: .error, hash, error.localizedDescription)
                }
            }
            
            // Migrate bookmarks
            if let bookmarksData = UserDefaults.standard.data(forKey: "DevReader.Bookmarks.v1.\(hash)"),
               let bookmarks = try? JSONDecoder().decode([Int].self, from: bookmarksData) {
                let bookmarksURL = dataDirectory.appendingPathComponent("bookmarks_\(hash).json")
                do {
                    try save(bookmarks, to: bookmarksURL)
                    UserDefaults.standard.removeObject(forKey: "DevReader.Bookmarks.v1.\(hash)")
                    os_log("Migrated bookmarks for hash: %{public}@", log: logger, type: .info, hash)
                } catch {
                    os_log("Failed to migrate bookmarks for hash %{public}@: %{public}@", log: logger, type: .error, hash, error.localizedDescription)
                }
            }
        }
        
        os_log("Migration completed", log: logger, type: .info)
    }
    
    // MARK: - Backup System
    static func createBackup() throws -> URL {
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        
        let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).json")
        let allData = try exportAllData()
        try save(allData, to: backupURL)
        
        os_log("Created backup: %{public}@", log: logger, type: .info, backupURL.path)
        return backupURL
    }
    
    static func restoreFromBackup(_ backupURL: URL) throws {
        let backupData = try load(DevReaderData.self, from: backupURL)
        try importAllData(backupData)
        os_log("Restored from backup: %{public}@", log: logger, type: .info, backupURL.path)
    }
    
    // MARK: - Export/Import
    static func exportAllData() throws -> DevReaderData {
        ensureDirectories()
        
        let library = loadOptional([LibraryItem].self, from: libraryPath()) ?? []
        let recentDocs = loadOptional([URL].self, from: recentsPath()) ?? []
        let pinnedDocs = loadOptional([URL].self, from: pinnedPath()) ?? []
        
        return DevReaderData(
            library: library,
            recentDocuments: recentDocs.map { $0.absoluteString },
            pinnedDocuments: pinnedDocs.map { $0.absoluteString },
            exportDate: Date(),
            version: "2.0"
        )
    }
    
    static func importAllData(_ data: DevReaderData) throws {
        ensureDirectories()
        
        // Import library
        try save(data.library, to: libraryPath())
        
        // Import recent and pinned documents
        let recentURLs = data.recentDocuments.compactMap { URL(string: $0) }
        let pinnedURLs = data.pinnedDocuments.compactMap { URL(string: $0) }
        try save(recentURLs, to: recentsPath())
        try save(pinnedURLs, to: pinnedPath())
        
        os_log("Imported data with %d library items", log: logger, type: .info, data.library.count)
    }
    
    // MARK: - Cleanup
    static func cleanupOldBackups(keepCount: Int = 10) {
        let backups = (try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let sortedBackups = backups.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
        
        for backup in sortedBackups.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: backup)
        }
        
        os_log("Cleaned up old backups, keeping %d", log: logger, type: .info, keepCount)
    }
    
    // MARK: - Data Validation
    static func validateDataIntegrity() -> [String] {
        var issues: [String] = []
        
        // Check if data directory exists
        if !FileManager.default.fileExists(atPath: dataDirectory.path) {
            issues.append("Data directory missing")
        }
        
        // Check for corrupted JSON files
        let jsonFiles = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in jsonFiles where file.pathExtension == "json" {
            do {
                _ = try Data(contentsOf: file)
            } catch {
                issues.append("Corrupted file: \(file.lastPathComponent)")
            }
        }
        
        return issues
    }
}

// MARK: - Data Structures
struct DevReaderData: Codable {
    let library: [LibraryItem]
    let recentDocuments: [String]
    let pinnedDocuments: [String]
    let exportDate: Date
    let version: String
}

// MARK: - Extensions
extension DateFormatter {
    func apply(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}
