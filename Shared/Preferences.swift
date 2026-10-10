//
//  Preferences.swift
//  MailCorrector
//
//  Non-secret preferences shared between the host app and the Mail extension
//  via an App Group. (Secrets like the API key live in the Keychain instead.)
//

import Foundation

/// Shared, non-secret preferences backed by an App Group `UserDefaults`.
struct Preferences {

    /// The App Group identifier shared by the app and extension.
    static let appGroupID = "group.com.myself.MailCorrector"

    private enum Keys {
        static let provider = "selectedProvider"
        static func model(for provider: Provider) -> String { "selectedModel.\(provider.rawValue)" }
    }

    private let defaults: UserDefaults

    /// Creates the store. Falls back to `.standard` if the App Group is
    /// unavailable (e.g. entitlement missing), so reads/writes never crash.
    init() {
        defaults = UserDefaults(suiteName: Preferences.appGroupID) ?? .standard
    }

    /// The user's selected provider.
    var provider: Provider {
        get {
            guard let raw = defaults.string(forKey: Keys.provider),
                  let provider = Provider(rawValue: raw) else {
                return .default
            }
            return provider
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Keys.provider)
        }
    }

    /// The selected model ID for a given provider (falls back to its default).
    func modelID(for provider: Provider) -> String {
        if let stored = defaults.string(forKey: Keys.model(for: provider)),
           provider.models.contains(where: { $0.id == stored }) {
            return stored
        }
        return provider.defaultModel.id
    }

    /// Sets the selected model ID for a given provider.
    nonmutating func setModelID(_ id: String, for provider: Provider) {
        defaults.set(id, forKey: Keys.model(for: provider))
    }
}
