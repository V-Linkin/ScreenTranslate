import Foundation
import Security

/// Keychain 辅助工具 - 安全存储 API Key
class KeychainHelper {

    private static let service = "com.screentranslate.app"

    /// 保存字符串到 Keychain
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed: \(status)")
        }
    }

    /// 从 Keychain 读取字符串
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// 删除 Keychain 中的值
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 便捷方法

    static func saveGoogleAPIKey(_ key: String) {
        save(key: "google_api_key", value: key)
    }

    static func loadGoogleAPIKey() -> String? {
        load(key: "google_api_key")
    }

    static func saveBaiduAppID(_ id: String) {
        save(key: "baidu_app_id", value: id)
    }

    static func loadBaiduAppID() -> String? {
        load(key: "baidu_app_id")
    }

    static func saveBaiduSecretKey(_ key: String) {
        save(key: "baidu_secret_key", value: key)
    }

    static func loadBaiduSecretKey() -> String? {
        load(key: "baidu_secret_key")
    }

    static func saveDeepLAPIKey(_ key: String) {
        save(key: "deepl_api_key", value: key)
    }

    static func loadDeepLAPIKey() -> String? {
        load(key: "deepl_api_key")
    }
}
