import Foundation
import Combine
import os.log

/// Enhanced persistence service with collision prevention and atomic writes
@MainActor
class EnhancedPersistenceService: ObservableObject {
    static let shared = EnhancedPersistenceService()

    private let logger = AppLog.persistence
    private let fileManager = FileManager.default

    init() {}

    // MARK: - Collision-Safe Key Generation

    /// Generates a collision-safe key using content fingerprint (first 64KB SHA256) when
    /// available, falling back to path hash. Content fingerprint survives file moves.
    func generateKey(_ base: String, for url: URL?, scope: String? = nil) -> String {
        guard let url = url else { return base }

        let uniqueId = PersistenceService.contentFingerprint(for: url)
            ?? PersistenceService.stableHash(for: url)

        if let scope = scope {
            return "\(base).\(scope).\(uniqueId)"
        }

        return "\(base).\(uniqueId)"
    }

    /// Legacy key using path-based hash (used for migration fallback)
    func legacyKey(_ base: String, for url: URL?) -> String {
        guard let url = url else { return base }
        return "\(base).\(PersistenceService.stableHash(for: url))"
    }
    
    // MARK: - Atomic Operations
    
    /// Atomically saves data with collision prevention
    func saveCodable<T: Codable>(_ data: T, forKey key: String, url: URL? = nil) throws {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        try JSONStorageService.save(data, to: fileURL)
        os_log("Saved data for key: %{public}@", log: logger, type: .debug, finalKey)
    }
    
    /// Loads data with validation
    func loadCodable<T: Codable>(_ type: T.Type, forKey key: String, url: URL? = nil) -> T? {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        return JSONStorageService.loadOptional(type, from: fileURL)
    }
    
    /// Loads data trying content-fingerprint key first, then falls back to legacy path-hash key.
    /// If found at legacy key, copies to new key and deletes old.
    func loadCodableWithMigration<T: Codable>(_ type: T.Type, forKey key: String, url: URL? = nil) -> T? {
        // Try new content-fingerprint key first
        if let result = loadCodable(type, forKey: key, url: url) {
            return result
        }

        // Fall back to legacy path-hash key
        guard let url = url else { return nil }
        let legacy = legacyKey(key, for: url)
        let newKey = generateKey(key, for: url)
        guard legacy != newKey else { return nil } // same key, no migration needed

        let legacyURL = JSONStorageService.dataDirectory.appendingPathComponent("\(legacy).json")
        guard let result = JSONStorageService.loadOptional(type, from: legacyURL) else { return nil }

        // Migrate: save to new key and delete old
        let newURL = JSONStorageService.dataDirectory.appendingPathComponent("\(newKey).json")
        try? JSONStorageService.save(result, to: newURL)
        try? fileManager.removeItem(at: legacyURL)
        os_log("Migrated data from legacy key %{public}@ to %{public}@", log: logger, type: .info, legacy, newKey)

        return result
    }

    // MARK: - Data Validation
    
    /// Typed validation — checks that the file decodes with JSONDecoder.
    func validateData<T: Codable>(_ type: T.Type, forKey key: String, url: URL? = nil) -> Bool {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")

        guard fileManager.fileExists(atPath: fileURL.path) else { return false }

        do {
            let data = try Data(contentsOf: fileURL)
            _ = try JSONDecoder().decode(type, from: data)
            return true
        } catch {
            os_log("Data validation failed for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return false
        }
    }

    /// Untyped validation — checks that the file contains valid JSON.
    func validateData(forKey key: String, url: URL? = nil) -> Bool {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")

        guard fileManager.fileExists(atPath: fileURL.path) else { return false }

        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else { return false }
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            os_log("Data validation failed for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return false
        }
    }
    
    /// Recovers corrupted data by clearing it
    func recoverCorruptedData(forKey key: String, url: URL? = nil) {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        
        if !validateData(forKey: key, url: url) {
            try? fileManager.removeItem(at: fileURL)
            os_log("Recovered corrupted data for key: %{public}@", log: logger, type: .info, finalKey)
        }
    }
    
    // MARK: - Migration Support
    
    /// Migrates data from old format
    func migrateData<T: Codable>(_ type: T.Type, forKey key: String, url: URL? = nil, migration: (Data) throws -> T) -> T? {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try migration(data)
        } catch {
            os_log("Migration failed for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Clears all data for a specific PDF. Returns the number of files that failed to delete.
    @discardableResult
    func clearData(for url: URL) -> Int {
        let baseKeys = ["DevReader.Notes.v1", "DevReader.PageNotes.v1", "DevReader.Tags.v1", "DevReader.Annotations.v1"]
        var failures = 0

        for baseKey in baseKeys {
            let finalKey = generateKey(baseKey, for: url)
            let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                failures += 1
                os_log("Failed to delete %{public}@: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            }
        }

        if failures == 0 {
            os_log("Cleared all data for PDF: %{public}@", log: logger, type: .info, url.lastPathComponent)
        } else {
            os_log("Partially cleared data for PDF: %{public}@ (%d failures)", log: logger, type: .error, url.lastPathComponent, failures)
        }
        return failures
    }
    
    /// Deletes data for a single key
    func deleteKey(_ key: String) {
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        try? fileManager.removeItem(at: fileURL)
        // Also clean up any temp/backup files
        try? fileManager.removeItem(at: fileURL.appendingPathExtension(JSONStorageService.tempExtension))
        try? fileManager.removeItem(at: fileURL.appendingPathExtension(JSONStorageService.backupExtension))
        os_log("Deleted data for key: %{public}@", log: logger, type: .debug, key)
    }

    /// Clears all persistence data
    func clearAllData() {
        try? fileManager.removeItem(at: JSONStorageService.dataDirectory)
        JSONStorageService.ensureDirectories()
        os_log("Cleared all persistence data", log: logger, type: .info)
    }

    // MARK: - Backup Restore

    /// Attempts to restore from a `.bak` file for the given key.
    /// Returns `true` if a backup was found and restored.
    func restoreBackup(forKey key: String, url: URL? = nil) -> Bool {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        let backupURL = fileURL.appendingPathExtension(JSONStorageService.backupExtension)

        guard fileManager.fileExists(atPath: backupURL.path) else { return false }

        do {
            try? fileManager.removeItem(at: fileURL)
            try fileManager.copyItem(at: backupURL, to: fileURL)
            os_log("Restored backup for key: %{public}@", log: logger, type: .info, finalKey)
            return true
        } catch {
            os_log("Backup restore failed for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return false
        }
    }
}
