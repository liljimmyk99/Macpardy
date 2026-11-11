//
//  HostTokenStore.swift
//  Macpardy
//
//  Where the external buzzer server's host token is kept (#104): the Keychain, never
//  `UserDefaults`. The token is never logged.
//

import Foundation
import Security

protocol HostTokenStore: AnyObject {
    /// The saved token, or nil when none is set.
    func token() -> String?
    /// Saves the token; an empty one removes it.
    func setToken(_ token: String)
}

extension HostTokenStore {
    var hasToken: Bool { token()?.isEmpty == false }
}

/// A generic-password Keychain item for the app.
final class KeychainHostTokenStore: HostTokenStore {

    private let service: String
    private let account = "buzzer-host-token"

    init(service: String = "jbkiv.Macpardy.buzzer") {
        self.service = service
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func token() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            SecItemDelete(query as CFDictionary)
            AppLogger.buzzer.info("Host token removed from the Keychain")
            return
        }
        let data = Data(trimmed.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let added = SecItemAdd(item as CFDictionary, nil)
            if added != errSecSuccess { AppLogger.buzzer.error("Couldn't save the host token to the Keychain (OSStatus \(added))") }
        } else if status != errSecSuccess {
            AppLogger.buzzer.error("Couldn't update the host token in the Keychain (OSStatus \(status))")
        } else {
            AppLogger.buzzer.info("Host token saved to the Keychain")
        }
    }
}

/// For tests and previews.
final class InMemoryHostTokenStore: HostTokenStore {
    private var value: String?
    init(token: String? = nil) { value = token }
    func token() -> String? { value }
    func setToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        value = trimmed.isEmpty ? nil : trimmed
    }
}
