import Foundation

// Centralized persistence helpers to keep UserDefaults usage consistent
// and safely handle Codable save/load with namespaced keys.
enum PersistenceService {
    // Builds a namespaced key. Optionally includes a per-file hash to scope data to a document.
    static func key(_ base: String, for url: URL?) -> String {
        guard let u = url else { return base }
        return base + "." + String(u.path.hashValue)
    }

    // MARK: - Codable
    static func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Primitives
    static func saveInt(_ value: Int, forKey key: String) { UserDefaults.standard.set(value, forKey: key) }
    static func loadInt(forKey key: String) -> Int? {
        if UserDefaults.standard.object(forKey: key) == nil { return nil }
        return UserDefaults.standard.integer(forKey: key)
    }

    static func saveBool(_ value: Bool, forKey key: String) { UserDefaults.standard.set(value, forKey: key) }
    static func loadBool(forKey key: String) -> Bool? {
        if UserDefaults.standard.object(forKey: key) == nil { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func delete(forKey key: String) { UserDefaults.standard.removeObject(forKey: key) }
}


