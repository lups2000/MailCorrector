//
//  KeychainStore.swift
//  MailCorrector
//
//  A small wrapper around the Security framework for storing and reading
//  the OpenAI API key. Shared between the host app and the Mail extension
//  via a common keychain access group so both processes read the same item.
//

import Foundation
import Security

/// Errors surfaced by `KeychainStore`.
enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain error (\(status)): \(message)"
        case .dataEncodingFailed:
            return "Could not encode the value for storage."
        }
    }
}

/// Stores and retrieves the OpenAI API key in the shared keychain access group.
///
/// Both the host app and the Mail extension declare the same
/// `keychain-access-groups` entitlement, so an item written by one target is
/// readable by the other.
struct KeychainStore {

    /// Shared configuration describing the single API-key item.
    struct Configuration {
        /// Service identifier for the keychain item.
        let service: String
        /// Account name for the keychain item.
        let account: String
        /// The keychain access group shared between the app and extension.
        ///
        /// The value is matched against the team-prefixed group declared in
        /// each target's entitlements; the system resolves the prefix.
        let accessGroup: String
    }

    /// The default configuration for the OpenAI API key.
    static let openAIKey = Configuration(
        service: "com.myself.MailCorrector.openai",
        account: "api-key",
        accessGroup: "com.myself.MailCorrector.shared"
    )

    /// Configuration for a specific provider's API key (one item per provider).
    static func configuration(for provider: Provider) -> Configuration {
        Configuration(
            service: "com.myself.MailCorrector.apikey",
            account: provider.rawValue,
            accessGroup: "com.myself.MailCorrector.shared"
        )
    }

    let configuration: Configuration

    init(configuration: Configuration = KeychainStore.openAIKey) {
        self.configuration = configuration
    }

    /// Convenience: a store for a specific provider's key.
    init(provider: Provider) {
        self.configuration = KeychainStore.configuration(for: provider)
    }

    // MARK: - Public API

    /// Saves (or replaces) the API key. Passing an empty string deletes the item.
    func save(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try delete()
            return
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }

        // Try to update an existing item first.
        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery()
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    /// Reads the stored API key, or `nil` if none is stored.
    func read() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes the stored API key, if present.
    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Convenience flag indicating whether a key is currently stored.
    var hasKey: Bool {
        (try? read())?.isEmpty == false
    }

    // MARK: - Private

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.service,
            kSecAttrAccount as String: configuration.account,
            kSecAttrAccessGroup as String: configuration.accessGroup
        ]
    }
}
