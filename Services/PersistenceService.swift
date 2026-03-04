import Foundation
import CryptoKit
import os.log

// Enhanced persistence service with JSON file-based storage
nonisolated enum PersistenceService {
    private static let logger = AppLog.persistence
    // Thread-safe one-time migration using Swift's static let guarantee (dispatch_once)
    private static let _migration: Void = {
        JSONStorageService.migrateFromUserDefaults()
        if !FileManager.default.fileExists(atPath: JSONStorageService.dataDirectory.path) {
            let msg = "Failed to create data directory at \(JSONStorageService.dataDirectory.path)"
            os_log("CRITICAL: %{public}@", log: AppLog.persistence, type: .fault, msg)
            UserDefaults.standard.set(msg, forKey: "initializationError")
        }
    }()

    /// Deterministic hash of a URL path using SHA256. Stable across app launches.
    static func stableHash(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.path.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// Content-based fingerprint: SHA256 of the first 64KB of the file.
    /// Returns nil if the file can't be read or is empty.
    static func contentFingerprint(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let chunk = handle.readData(ofLength: 65_536)
        guard !chunk.isEmpty else { return nil }
        let digest = SHA256.hash(data: chunk)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    // Builds a namespaced key with proper PDF scoping to prevent collisions.
    // Prefers content fingerprint (survives file moves) with path-hash fallback.
    static func key(_ base: String, for url: URL?) -> String {
        guard let u = url else { return base }
        let hash = contentFingerprint(for: u) ?? stableHash(for: u)
        return base + "." + hash
    }

    /// Legacy key using path-hash only (for migration fallback)
    static func legacyKey(_ base: String, for url: URL?) -> String {
        guard let u = url else { return base }
        return base + "." + stableHash(for: u)
    }

    // Scoped key generation for namespacing
    static func key(_ base: String, for url: URL?, withScope scope: String) -> String {
        guard let u = url else { return base }
        let hash = contentFingerprint(for: u) ?? stableHash(for: u)
        return base + "." + scope + "." + hash
    }

    // Initialize JSON-based persistence
    static func initialize() {
        _ = _migration
    }

    // MARK: - JSON File-based Storage
    @discardableResult
    static func saveCodable<T: Codable>(_ value: T, forKey key: String) throws -> Bool {
        let url = getFilePath(for: key)
        try JSONStorageService.save(value, to: url)
        os_log("Successfully saved data for key: %{public}@", log: logger, type: .debug, key)
        return true
    }

    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let url = getFilePath(for: key)
        let result = JSONStorageService.loadOptional(type, from: url)
        if result == nil {
            os_log("No data found for key: %{public}@", log: logger, type: .debug, key)
        }
        return result
    }

    /// Tries loading with the given key first; if nil and legacyKey differs, tries the
    /// legacy path-hash key and migrates data to the new key.
    static func loadCodableWithMigration<T: Codable>(_ type: T.Type, forKey key: String, legacyKey: String) -> T? {
        if let result = loadCodable(type, forKey: key) {
            return result
        }
        guard key != legacyKey else { return nil }
        guard let result = loadCodable(type, forKey: legacyKey) else { return nil }
        // Migrate: save to new key and delete old only if save succeeds
        do {
            try saveCodable(result, forKey: key)
            delete(forKey: legacyKey)
            os_log("Migrated data from legacy key %{public}@ to %{public}@", log: logger, type: .info, legacyKey, key)
        } catch {
            os_log("Migration save failed for key %{public}@, keeping legacy: %{public}@", log: logger, type: .error, key, error.localizedDescription)
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
        } else if key == "DevReader.Web.Bookmarks.v1" {
            return JSONStorageService.webBookmarksPath()
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
        } else if key.hasPrefix("DevReader.Annotations.v1.") {
            let hash = String(key.dropFirst("DevReader.Annotations.v1.".count))
            return JSONStorageService.dataDirectory.appendingPathComponent("annotations_\(hash).json")
        } else {
            // Fallback to data directory
            return JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        }
    }

    // MARK: - Primitives with JSON Storage
    @discardableResult
    static func saveInt(_ value: Int, forKey key: String) throws -> Bool {
        let url = getFilePath(for: key)
        try JSONStorageService.save(value, to: url)
        os_log("Saved int %d for key: %{public}@", log: logger, type: .debug, value, key)
        return true
    }
    
    static func loadInt(forKey key: String) -> Int? {
        let url = getFilePath(for: key)
        let result = JSONStorageService.loadOptional(Int.self, from: url)
        if let value = result {
            os_log("Loaded int %d for key: %{public}@", log: logger, type: .debug, value, key)
        }
        return result
    }

    @discardableResult
    static func saveBool(_ value: Bool, forKey key: String) throws -> Bool {
        let url = getFilePath(for: key)
        try JSONStorageService.save(value, to: url)
        os_log("Saved bool %{public}@ for key: %{public}@", log: logger, type: .debug, String(value), key)
        return true
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
    /// Typed validation — checks that the file decodes with JSONDecoder as the
    /// expected type. Matches the strictness of loadCodable, avoiding false
    /// positives from JSONSerialization's more permissive parsing.
    static func validateData<T: Codable>(_ type: T.Type, forKey key: String) -> Bool {
        let url = getFilePath(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        do {
            let data = try Data(contentsOf: url)
            _ = try JSONDecoder().decode(type, from: data)
            return true
        } catch {
            os_log("Invalid data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
            return false
        }
    }

    /// Untyped validation — checks that the file contains valid JSON via
    /// JSONSerialization. Prefer the typed overload when the expected type is known.
    static func validateData(forKey key: String) -> Bool {
        let url = getFilePath(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return false }
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            os_log("Invalid data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
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


