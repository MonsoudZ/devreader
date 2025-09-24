import Foundation
import os.log

// Centralized persistence helpers to keep UserDefaults usage consistent
// and safely handle Codable save/load with namespaced keys.
enum PersistenceService {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "Persistence")
    
    // Builds a namespaced key. Optionally includes a per-file hash to scope data to a document.
    static func key(_ base: String, for url: URL?) -> String {
        guard let u = url else { return base }
        return base + "." + String(u.path.hashValue)
    }

    // MARK: - Codable with Error Recovery
    static func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
            os_log("Successfully saved data for key: %{public}@", log: logger, type: .debug, key)
        } catch {
            os_log("Failed to encode data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
        }
    }

    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { 
            os_log("No data found for key: %{public}@", log: logger, type: .debug, key)
            return nil 
        }
        
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            os_log("Successfully loaded data for key: %{public}@", log: logger, type: .debug, key)
            return result
        } catch {
            os_log("Failed to decode data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    // MARK: - Primitives with Validation
    static func saveInt(_ value: Int, forKey key: String) { 
        UserDefaults.standard.set(value, forKey: key)
        os_log("Saved int %d for key: %{public}@", log: logger, type: .debug, value, key)
    }
    
    static func loadInt(forKey key: String) -> Int? {
        if UserDefaults.standard.object(forKey: key) == nil { return nil }
        let value = UserDefaults.standard.integer(forKey: key)
        os_log("Loaded int %d for key: %{public}@", log: logger, type: .debug, value, key)
        return value
    }

    static func saveBool(_ value: Bool, forKey key: String) { 
        UserDefaults.standard.set(value, forKey: key)
        os_log("Saved bool %{public}@ for key: %{public}@", log: logger, type: .debug, String(value), key)
    }
    
    static func loadBool(forKey key: String) -> Bool? {
        if UserDefaults.standard.object(forKey: key) == nil { return nil }
        let value = UserDefaults.standard.bool(forKey: key)
        os_log("Loaded bool %{public}@ for key: %{public}@", log: logger, type: .debug, String(value), key)
        return value
    }

    static func delete(forKey key: String) { 
        UserDefaults.standard.removeObject(forKey: key)
        os_log("Deleted data for key: %{public}@", log: logger, type: .debug, key)
    }
    
    // MARK: - Data Validation and Recovery
    static func validateData(forKey key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key) else { return false }
        
        // Check if data is valid JSON
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            os_log("Invalid JSON data for key %{public}@: %{public}@", log: logger, type: .error, key, error.localizedDescription)
            return false
        }
    }
    
    static func recoverCorruptedData(forKey key: String) {
        os_log("Attempting to recover corrupted data for key: %{public}@", log: logger, type: .info, key)
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    static func clearAllData() {
        let domain = Bundle.main.bundleIdentifier ?? "DevReader"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        os_log("Cleared all persistent data", log: logger, type: .info)
    }
}


