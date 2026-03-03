import Foundation
import CryptoKit
import Combine
import os.log

/// Enhanced persistence service with collision prevention and atomic writes
@MainActor
class EnhancedPersistenceService: ObservableObject {
    static let shared = EnhancedPersistenceService()

    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "EnhancedPersistence")
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Collision-Safe Key Generation

    /// Generates a collision-safe key using a deterministic SHA256 hash of the file path.
    /// Only the path is used — file attributes like size/date are excluded to prevent
    /// keys from changing when files are touched, synced, or re-downloaded.
    func generateKey(_ base: String, for url: URL?, scope: String? = nil) -> String {
        guard let url = url else { return base }

        let uniqueId = PersistenceService.stableHash(for: url)

        if let scope = scope {
            return "\(base).\(scope).\(uniqueId)"
        }

        return "\(base).\(uniqueId)"
    }
    
    // MARK: - Atomic Operations
    
    /// Atomically saves data with collision prevention
    func saveCodable<T: Codable>(_ data: T, forKey key: String, url: URL? = nil) throws {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        
        // Ensure directory exists
        JSONStorageService.ensureDirectories()
        
        // Create temporary file for atomic write
        let tempURL = fileURL.appendingPathExtension("tmp")
        let backupURL = fileURL.appendingPathExtension("bak")
        
        do {
            // Encode data
            let jsonData = try JSONEncoder().encode(data)

            // Write to temporary file
            try jsonData.write(to: tempURL)

            if fileManager.fileExists(atPath: fileURL.path) {
                // Create backup before replacing
                try? fileManager.removeItem(at: backupURL)
                try fileManager.copyItem(at: fileURL, to: backupURL)

                // Atomic replace
                _ = try fileManager.replaceItem(at: fileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                // First write — just move into place
                try fileManager.moveItem(at: tempURL, to: fileURL)
            }

            // Clean up backup
            try? fileManager.removeItem(at: backupURL)

            os_log("Atomically saved data for key: %{public}@", log: logger, type: .debug, finalKey)

        } catch {
            // Restore from backup if atomic write failed
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: fileURL)
                try? fileManager.moveItem(at: backupURL, to: fileURL)
            }

            // Clean up temporary file
            try? fileManager.removeItem(at: tempURL)

            os_log("Failed to save data atomically for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            throw error
        }
    }
    
    /// Loads data with validation
    func loadCodable<T: Codable>(_ type: T.Type, forKey key: String, url: URL? = nil) -> T? {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let result = try JSONDecoder().decode(type, from: data)
            
            os_log("Loaded data for key: %{public}@", log: logger, type: .debug, finalKey)
            return result
            
        } catch {
            os_log("Failed to load data for key: %{public}@, error: %{public}@", log: logger, type: .error, finalKey, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Data Validation
    
    /// Validates data integrity
    func validateData(forKey key: String, url: URL? = nil) -> Bool {
        let finalKey = generateKey(key, for: url)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return false }
        
        do {
            let data = try Data(contentsOf: fileURL)
            // Try to decode as generic JSON to validate structure
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
    
    /// Clears all data for a specific PDF
    func clearData(for url: URL) {
        let baseKeys = ["DevReader.Notes.v1", "DevReader.PageNotes.v1", "DevReader.Tags.v1"]
        
        for baseKey in baseKeys {
            let finalKey = generateKey(baseKey, for: url)
            let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
            try? fileManager.removeItem(at: fileURL)
        }
        
        os_log("Cleared all data for PDF: %{public}@", log: logger, type: .info, url.lastPathComponent)
    }
    
    /// Deletes data for a single key
    func deleteKey(_ key: String) {
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        try? fileManager.removeItem(at: fileURL)
        // Also clean up any temp/backup files
        try? fileManager.removeItem(at: fileURL.appendingPathExtension("tmp"))
        try? fileManager.removeItem(at: fileURL.appendingPathExtension("bak"))
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
        let backupURL = fileURL.appendingPathExtension("bak")

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
