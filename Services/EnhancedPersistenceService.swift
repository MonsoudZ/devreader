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
        do {
            try JSONStorageService.save(result, to: newURL)
            // Only delete legacy after successful save to prevent data loss
            do {
                try fileManager.removeItem(at: legacyURL)
            } catch {
                os_log("Failed to clean up legacy key %{public}@: %{public}@", log: logger, type: .error, legacy, error.localizedDescription)
            }
            os_log("Migrated data from legacy key %{public}@ to %{public}@", log: logger, type: .info, legacy, newKey)
        } catch {
            os_log("Migration save failed for key %{public}@: %{public}@ — keeping legacy data", log: logger, type: .error, newKey, error.localizedDescription)
        }

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
    
    /// Recovers corrupted data by attempting backup restore first, then clearing as last resort
    func recoverCorruptedData(forKey key: String, url: URL? = nil) {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")

        guard !validateData(forKey: key, url: url) else { return }

        // Try restoring from backup before deleting
        if restoreBackup(forKey: key, url: url) {
            os_log("Recovered corrupted data from backup for key: %{public}@", log: logger, type: .info, finalKey)
            return
        }

        // No backup available — delete corrupted file
        try? fileManager.removeItem(at: fileURL)
        os_log("No backup available, deleted corrupted data for key: %{public}@", log: logger, type: .info, finalKey)
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
        let baseKeys = ["DevReader.Notes.v1", "DevReader.PageNotes.v1", "DevReader.Tags.v1", "DevReader.Annotations.v1", "DevReader.Bookmarks.v1", "DevReader.Session.v1"]
        var failures = 0

        for baseKey in baseKeys {
            let finalKey = generateKey(baseKey, for: url)
            let primaryURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")

            // Delete primary file and associated .bak/.tmp files
            for fileURL in [primaryURL,
                            primaryURL.appendingPathExtension(JSONStorageService.backupExtension),
                            primaryURL.appendingPathExtension(JSONStorageService.tempExtension)] {
                guard fileManager.fileExists(atPath: fileURL.path) else { continue }
                do {
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    failures += 1
                    os_log("Failed to delete %{public}@: %{public}@", log: logger, type: .error, fileURL.lastPathComponent, error.localizedDescription)
                }
            }
        }

        // Also clean up legacy-keyed files (path-hash format) if different from content-fingerprint key
        let hash = PersistenceService.stableHash(for: url)
        let legacyPrefixes = ["notes_", "page_notes_", "tags_", "annotations_", "bookmarks_", "session_"]
        for prefix in legacyPrefixes {
            let legacyURL = JSONStorageService.dataDirectory.appendingPathComponent("\(prefix)\(hash).json")
            if fileManager.fileExists(atPath: legacyURL.path) {
                do {
                    try fileManager.removeItem(at: legacyURL)
                } catch {
                    failures += 1
                }
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
        let filesToDelete = [
            fileURL,
            fileURL.appendingPathExtension(JSONStorageService.tempExtension),
            fileURL.appendingPathExtension(JSONStorageService.backupExtension)
        ]
        for file in filesToDelete where fileManager.fileExists(atPath: file.path) {
            do {
                try fileManager.removeItem(at: file)
            } catch {
                os_log("Failed to delete %{public}@: %{public}@", log: logger, type: .error, file.lastPathComponent, error.localizedDescription)
            }
        }
        os_log("Deleted data for key: %{public}@", log: logger, type: .debug, key)
    }

    /// Clears all persistence data
    func clearAllData() {
        do {
            try fileManager.removeItem(at: JSONStorageService.dataDirectory)
        } catch {
            os_log("Failed to clear data directory: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
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
            // Remove existing corrupted file first; if it doesn't exist that's fine
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.copyItem(at: backupURL, to: fileURL)
            os_log("Restored backup for key: %{public}@", log: logger, type: .info, finalKey)
            return true
        } catch {
            os_log("Backup restore failed for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return false
        }
    }
}
