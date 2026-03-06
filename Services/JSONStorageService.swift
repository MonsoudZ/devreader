import Foundation
import os.log

/// Enhanced JSON file-based storage system for better performance and reliability
nonisolated enum JSONStorageService {
    private static let logger = AppLog.persistence

    /// File extensions used for atomic write intermediaries.
    static let tempExtension = "tmp"
    static let backupExtension = "bak"

    // MARK: - Storage Locations
    static var appSupportURL: URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("DevReader", isDirectory: true)
        }
        return base.appendingPathComponent("DevReader", isDirectory: true)
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
        let hash = PersistenceService.stableHash(for: pdfURL)
        return dataDirectory.appendingPathComponent("notes_\(hash).json")
    }

    static func sessionPath(for pdfURL: URL) -> URL {
        let hash = PersistenceService.stableHash(for: pdfURL)
        return dataDirectory.appendingPathComponent("session_\(hash).json")
    }

    static func bookmarksPath(for pdfURL: URL) -> URL {
        let hash = PersistenceService.stableHash(for: pdfURL)
        return dataDirectory.appendingPathComponent("bookmarks_\(hash).json")
    }
    
    static func recentsPath() -> URL {
        dataDirectory.appendingPathComponent("recents.json")
    }
    
    static func pinnedPath() -> URL {
        dataDirectory.appendingPathComponent("pinned.json")
    }

    static func webBookmarksPath() -> URL {
        dataDirectory.appendingPathComponent("web_bookmarks.json")
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
    
    /// Serial queue that serializes all file writes to prevent concurrent save corruption.
    private static let writeQueue = DispatchQueue(label: "com.monsoud.devreader.json-storage-write")

    // MARK: - JSON Operations
    static func save<T: Codable>(_ data: T, to url: URL) throws {
        ensureDirectories()
        let jsonData = try JSONEncoder().encode(data)

        // Serialize writes to the same destination to prevent race conditions
        try writeQueue.sync {
            // Atomic write to prevent corruption — UUID avoids collision on concurrent saves
            let tempURL = url.deletingPathExtension()
                .appendingPathExtension(UUID().uuidString)
                .appendingPathExtension(tempExtension)

            do {
                // Write to temporary file first
                try jsonData.write(to: tempURL)

                // Try atomic replace (works when target exists)
                do {
                    _ = try FileManager.default.replaceItem(
                        at: url, withItemAt: tempURL,
                        backupItemName: nil, options: [], resultingItemURL: nil
                    )
                } catch let replaceError as NSError where replaceError.domain == NSCocoaErrorDomain
                    && (replaceError.code == NSFileNoSuchFileError || replaceError.code == NSFileReadNoSuchFileError) {
                    // Target doesn't exist yet — move temp file into place
                    try FileManager.default.moveItem(at: tempURL, to: url)
                }

                os_log("Saved data atomically to: %{public}@", log: logger, type: .debug, url.path)
            } catch {
                // Clean up temporary file on failure
                try? FileManager.default.removeItem(at: tempURL)

                os_log("Failed to save data atomically: %{public}@", log: logger, type: .error, error.localizedDescription)
                throw error
            }
        }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).json")
        let allData = try exportAllData()
        try save(allData, to: backupURL)
        
        os_log("Created backup: %{public}@", log: logger, type: .info, backupURL.path)
        return backupURL
    }
    
    static func restoreFromBackup(_ backupURL: URL) throws {
        // Safety: create a pre-restore backup so we can recover if something goes wrong
        _ = try? createBackup()

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
        let webBookmarks = loadOptional([URL].self, from: webBookmarksPath()) ?? []

        // Export all per-PDF data files
        let annotationBundles = exportBundles(prefix: "annotations_") { (hash, file) -> AnnotationBundle? in
            guard let annotations = loadOptional([PDFAnnotationData].self, from: file), !annotations.isEmpty else { return nil }
            return AnnotationBundle(hash: hash, annotations: annotations)
        }

        let notesBundles = exportPerPDFNotes()
        let bookmarksBundles = exportBundles(prefix: "bookmarks_") { (hash, file) -> BookmarksBundle? in
            guard let bookmarks = loadOptional([Int].self, from: file), !bookmarks.isEmpty else { return nil }
            return BookmarksBundle(hash: hash, bookmarks: bookmarks)
        }
        let sessionBundles = exportSessionBundles()

        // Export sketches
        let sketchesKey = "DevReader.Sketches.v1"
        let sketchesFile = dataDirectory.appendingPathComponent("\(sketchesKey).json")
        let sketches = loadOptional([SketchItem].self, from: sketchesFile)

        return DevReaderData(
            library: library,
            recentDocuments: recentDocs.map { $0.absoluteString },
            pinnedDocuments: pinnedDocs.map { $0.absoluteString },
            webBookmarks: webBookmarks.map { $0.absoluteString },
            annotationBundles: annotationBundles.isEmpty ? nil : annotationBundles,
            notesBundles: notesBundles.isEmpty ? nil : notesBundles,
            bookmarksBundles: bookmarksBundles.isEmpty ? nil : bookmarksBundles,
            sessionBundles: sessionBundles.isEmpty ? nil : sessionBundles,
            sketches: sketches?.isEmpty == false ? sketches : nil,
            exportDate: Date(),
            version: "3.0"
        )
    }

    /// Generic helper to export per-PDF data files matching a filename prefix.
    private static func exportBundles<T>(prefix: String, transform: (String, URL) -> T?) -> [T] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { file -> T? in
            let name = file.deletingPathExtension().lastPathComponent
            guard name.hasPrefix(prefix) else { return nil }
            let hash = String(name.dropFirst(prefix.count))
            return transform(hash, file)
        }
    }

    private static func exportPerPDFNotes() -> [NotesBundle] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        // Group notes, page_notes, and tags by hash
        var notesMap: [String: [NoteItem]] = [:]
        var pageNotesMap: [String: [Int: String]] = [:]
        var tagsMap: [String: [String]] = [:]

        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            if name.hasPrefix("notes_") {
                // Skip page_notes_ files
                continue
            }
        }

        // Scan for notes files using the key pattern from NotesPersistenceService
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            if name.hasPrefix("DevReader.Notes.v1.") {
                let hash = String(name.dropFirst("DevReader.Notes.v1.".count))
                if let notes = loadOptional([NoteItem].self, from: file) {
                    notesMap[hash] = notes
                }
            } else if name.hasPrefix("DevReader.PageNotes.v1.") {
                let hash = String(name.dropFirst("DevReader.PageNotes.v1.".count))
                if let pageNotes = loadOptional([Int: String].self, from: file) {
                    pageNotesMap[hash] = pageNotes
                }
            } else if name.hasPrefix("DevReader.Tags.v1.") {
                let hash = String(name.dropFirst("DevReader.Tags.v1.".count))
                if let tags = loadOptional([String].self, from: file) {
                    tagsMap[hash] = tags
                }
            }
            // Also check legacy notes_ format from migration
            else if name.hasPrefix("notes_") {
                let hash = String(name.dropFirst("notes_".count))
                if let notes = loadOptional([NoteItem].self, from: file) {
                    notesMap[hash] = notes
                }
            } else if name.hasPrefix("page_notes_") {
                let hash = String(name.dropFirst("page_notes_".count))
                if let pageNotes = loadOptional([Int: String].self, from: file) {
                    pageNotesMap[hash] = pageNotes
                }
            } else if name.hasPrefix("tags_") {
                let hash = String(name.dropFirst("tags_".count))
                if let tags = loadOptional([String].self, from: file) {
                    tagsMap[hash] = tags
                }
            }
        }

        let allHashes = Set(notesMap.keys).union(pageNotesMap.keys).union(tagsMap.keys)
        return allHashes.compactMap { hash -> NotesBundle? in
            let notes = notesMap[hash] ?? []
            let pageNotes = pageNotesMap[hash]
            let tags = tagsMap[hash]
            guard !notes.isEmpty || pageNotes != nil || tags != nil else { return nil }
            return NotesBundle(hash: hash, notes: notes, pageNotes: pageNotes, tags: tags)
        }
    }

    private static func exportSessionBundles() -> [SessionBundle] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { file -> SessionBundle? in
            let name = file.deletingPathExtension().lastPathComponent
            // Match both session_ and DevReader.Session.v1. prefixed files
            let hash: String
            if name.hasPrefix("session_") {
                hash = String(name.dropFirst("session_".count))
            } else if name.hasPrefix("DevReader.Session.v1.") {
                hash = String(name.dropFirst("DevReader.Session.v1.".count))
            } else {
                return nil
            }
            guard let data = try? Data(contentsOf: file), !data.isEmpty else { return nil }
            return SessionBundle(hash: hash, data: data)
        }
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

        // Import web bookmarks (optional field for backward compatibility)
        if let webBookmarkStrings = data.webBookmarks {
            let webBookmarkURLs = webBookmarkStrings.compactMap { URL(string: $0) }
            try save(webBookmarkURLs, to: webBookmarksPath())
        }

        // Import annotation bundles
        if let bundles = data.annotationBundles {
            for bundle in bundles {
                let fileURL = dataDirectory.appendingPathComponent("annotations_\(bundle.hash).json")
                try save(bundle.annotations, to: fileURL)
            }
        }

        // Import notes bundles
        if let bundles = data.notesBundles {
            for bundle in bundles {
                let notesFile = dataDirectory.appendingPathComponent("DevReader.Notes.v1.\(bundle.hash).json")
                try save(bundle.notes, to: notesFile)
                if let pageNotes = bundle.pageNotes {
                    let pageNotesFile = dataDirectory.appendingPathComponent("DevReader.PageNotes.v1.\(bundle.hash).json")
                    try save(pageNotes, to: pageNotesFile)
                }
                if let tags = bundle.tags {
                    let tagsFile = dataDirectory.appendingPathComponent("DevReader.Tags.v1.\(bundle.hash).json")
                    try save(tags, to: tagsFile)
                }
            }
        }

        // Import bookmarks bundles
        if let bundles = data.bookmarksBundles {
            for bundle in bundles {
                let fileURL = dataDirectory.appendingPathComponent("bookmarks_\(bundle.hash).json")
                try save(bundle.bookmarks, to: fileURL)
            }
        }

        // Import session bundles
        if let bundles = data.sessionBundles {
            for bundle in bundles {
                let fileURL = dataDirectory.appendingPathComponent("session_\(bundle.hash).json")
                try bundle.data.write(to: fileURL)
            }
        }

        // Import sketches
        if let sketches = data.sketches {
            let sketchesFile = dataDirectory.appendingPathComponent("DevReader.Sketches.v1.json")
            try save(sketches, to: sketchesFile)
        }

        os_log("Imported data with %d library items, %d note bundles, %d sketches",
               log: logger, type: .info,
               data.library.count,
               data.notesBundles?.count ?? 0,
               data.sketches?.count ?? 0)
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
        
        // Check for corrupted JSON files (validate JSON structure, not just readability)
        let jsonFiles = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in jsonFiles where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                guard !data.isEmpty else {
                    issues.append("Empty file: \(file.lastPathComponent)")
                    continue
                }
                _ = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            } catch {
                issues.append("Corrupted file: \(file.lastPathComponent) — \(error.localizedDescription)")
            }
        }
        
        return issues
    }
}


