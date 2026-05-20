import Foundation
import Security

enum KeychainHelper {
    // Namespace all entries to this app's bundle ID to prevent cross-app Keychain collisions.
    private static let service = Bundle.main.bundleIdentifier ?? "com.example.fittrack"

    /// Saves (or overwrites) a string value under the given key.
    static func save(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Delete any existing entry first so SecItemAdd always succeeds.
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attrs: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            // ThisDeviceOnly: prevents iCloud Keychain sync, keeping secrets on-device.
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    /// Returns the string stored for the given key, or nil if absent.
    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the entry for the given key. Safe to call when the key does not exist.
    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
