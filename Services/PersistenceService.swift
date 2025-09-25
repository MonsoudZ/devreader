import Foundation
import os.log

// Enhanced persistence service with JSON file-based storage
enum PersistenceService {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "Persistence")
    private static var hasMigrated = false
    
    // Builds a namespaced key. Optionally includes a per-file hash to scope data to a document.
    static func key(_ base: String, for url: URL?) -> String {
        guard let u = url else { return base }
        return base + "." + String(u.path.hashValue)
    }
    
    // Initialize JSON-based persistence
    static func initialize() {
        if !hasMigrated {
            JSONStorageService.migrateFromUserDefaults()
            hasMigrated = true
        }
    }

    // MARK: - JSON File-based Storage
    static func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        // Determine file path based on key
        let url = getFilePath(for: key)
        do {
            try JSONStorageService.save(value, to: url)
            os_log("Successfully saved data for key: %{public}@", log: logger, type: .debug, key)
        } catch {
            os_log("Failed to save data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
        }
    }

    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let url = getFilePath(for: key)
        let result = JSONStorageService.loadOptional(type, from: url)
        if result == nil {
            os_log("No data found for key: %{public}@", log: logger, type: .debug, key)
        }
        return result
    }
    
    private static func getFilePath(for key: String) -> URL {
        if key == "DevReader.Library.v1" {
            return JSONStorageService.libraryPath()
        } else if key == "DevReader.Recents.v1" {
            return JSONStorageService.recentsPath()
        } else if key == "DevReader.Pinned.v1" {
            return JSONStorageService.pinnedPath()
        } else if key.hasPrefix("DevReader.Notes.v1.") {
            let hash = String(key.dropFirst("DevReader.Notes.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("notes_\(hash).json")
        } else if key.hasPrefix("DevReader.PageNotes.v1.") {
            let hash = String(key.dropFirst("DevReader.PageNotes.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("page_notes_\(hash).json")
        } else if key.hasPrefix("DevReader.Tags.v1.") {
            let hash = String(key.dropFirst("DevReader.Tags.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("tags_\(hash).json")
        } else if key.hasPrefix("DevReader.Session.v1.") {
            let hash = String(key.dropFirst("DevReader.Session.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("session_\(hash).json")
        } else if key.hasPrefix("DevReader.Bookmarks.v1.") {
            let hash = String(key.dropFirst("DevReader.Bookmarks.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("bookmarks_\(hash).json")
        } else {
            // Fallback to data directory
            return JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        }
    }

    // MARK: - Primitives with JSON Storage
    static func saveInt(_ value: Int, forKey key: String) { 
        let url = getFilePath(for: key)
        do {
            try JSONStorageService.save(value, to: url)
            os_log("Saved int %d for key: %{public}@", log: logger, type: .debug, value, key)
        } catch {
            os_log("Failed to save int for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
        }
    }
    
    static func loadInt(forKey key: String) -> Int? {
        let url = getFilePath(for: key)
        let result = JSONStorageService.loadOptional(Int.self, from: url)
        if let value = result {
            os_log("Loaded int %d for key: %{public}@", log: logger, type: .debug, value, key)
        }
        return result
    }

    static func saveBool(_ value: Bool, forKey key: String) { 
        let url = getFilePath(for: key)
        do {
            try JSONStorageService.save(value, to: url)
            os_log("Saved bool %{public}@ for key: %{public}@", log: logger, type: .debug, String(value), key)
        } catch {
            os_log("Failed to save bool for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
        }
    }
    
    static func loadBool(forKey key: String) -> Bool? {
        let url = getFilePath(for: key)
        let result = JSONStorageService.loadOptional(Bool.self, from: url)
        if let value = result {
            os_log("Loaded bool %{public}@ for key: %{public}@", log: logger, type: .debug, String(value), key)
        }
        return result
    }

    static func delete(forKey key: String) { 
        let url = getFilePath(for: key)
        JSONStorageService.delete(url: url)
        os_log("Deleted data for key: %{public}@", log: logger, type: .debug, key)
    }
    
    // MARK: - Data Validation and Recovery
    static func validateData(forKey key: String) -> Bool {
        let url = getFilePath(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        
        do {
            let data = try Data(contentsOf: url)
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            os_log("Invalid JSON data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
            return false
        }
    }
    
    static func recoverCorruptedData(forKey key: String) {
        os_log("Attempting to recover corrupted data for key: %{public}@", log: logger, type: .info, key)
        let url = getFilePath(for: key)
        JSONStorageService.delete(url: url)
    }
    
    static func clearAllData() {
        do {
            let dataDir = JSONStorageService.dataDirectory
            if FileManager.default.fileExists(atPath: dataDir.path) {
                try FileManager.default.removeItem(at: dataDir)
                os_log("Cleared all JSON data", log: logger, type: .info)
            }
        } catch {
            os_log("Failed to clear JSON data: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Backup and Restore
    static func createBackup() throws -> URL {
        return try JSONStorageService.createBackup()
    }
    
    static func restoreFromBackup(_ backupURL: URL) throws {
        try JSONStorageService.restoreFromBackup(backupURL)
    }
    
    static func exportAllData() throws -> DevReaderData {
        return try JSONStorageService.exportAllData()
    }
    
    static func importAllData(_ data: DevReaderData) throws {
        try JSONStorageService.importAllData(data)
    }
    
    static func validateDataIntegrity() -> [String] {
        return JSONStorageService.validateDataIntegrity()
    }
}


