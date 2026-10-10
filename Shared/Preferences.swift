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
        static let model = "selectedModel"
    }

    private let defaults: UserDefaults

    /// Creates the store. Falls back to `.standard` if the App Group is
    /// unavailable (e.g. entitlement missing), so reads/writes never crash.
    init() {
        defaults = UserDefaults(suiteName: Preferences.appGroupID) ?? .standard
    }

    /// The user's selected AI model.
    var model: AIModel {
        get {
            guard let raw = defaults.string(forKey: Keys.model),
                  let model = AIModel(rawValue: raw) else {
                return .default
            }
            return model
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Keys.model)
        }
    }
}
