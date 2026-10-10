//
//  Provider.swift
//  MailCorrector
//
//  The AI providers the app can talk to, each with its own models, endpoint,
//  and authentication style. Shared between the host app and the extension.
//
//  NOTE: Model IDs and endpoints change over time. Verify against each
//  provider's current documentation and update as needed.
//

import Foundation

/// A supported AI provider.
enum Provider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case gemini
    case openRouter

    var id: Self { self }

    /// The default provider.
    static let `default`: Provider = .openAI

    /// User-facing name.
    var title: String {
        switch self {
        case .openAI:     return "OpenAI"
        case .anthropic:  return "Anthropic (Claude)"
        case .gemini:     return "Google Gemini"
        case .openRouter: return "OpenRouter"
        }
    }

    /// Where the user obtains an API key (shown in Settings).
    var keysURL: URL {
        switch self {
        case .openAI:     return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic:  return URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini:     return URL(string: "https://aistudio.google.com/apikey")!
        case .openRouter: return URL(string: "https://openrouter.ai/keys")!
        }
    }

    /// Expected API-key prefix hint shown as the field placeholder.
    var keyPlaceholder: String {
        switch self {
        case .openAI:     return "sk-proj-…"
        case .anthropic:  return "sk-ant-…"
        case .gemini:     return "AIza…"
        case .openRouter: return "sk-or-…"
        }
    }

    /// The models offered for this provider, cheapest first.
    var models: [AIModel] {
        switch self {
        case .openAI:
            return [.init(id: "gpt-5-mini", hint: "Cheapest, fast"),
                    .init(id: "gpt-5", hint: "Balanced"),
                    .init(id: "gpt-5.1", hint: "Highest quality")]
        case .anthropic:
            return [.init(id: "claude-haiku-5-5", hint: "Cheapest, fast"),
                    .init(id: "claude-sonnet-5-5", hint: "Balanced"),
                    .init(id: "claude-opus-5-5", hint: "Highest quality")]
        case .gemini:
            return [.init(id: "gemini-3.5-flash", hint: "Cheapest, fast"),
                    .init(id: "gemini-3.8-flash", hint: "Latest flash"),
                    .init(id: "gemini-3.1-pro-preview", hint: "Highest quality")]
        case .openRouter:
            return [.init(id: "openai/gpt-5-mini", hint: "Cheap"),
                    .init(id: "anthropic/claude-sonnet-5-5", hint: "Balanced"),
                    .init(id: "google/gemini-3.8-flash", hint: "Fast")]
        }
    }

    /// The default model for this provider (the first/cheapest).
    var defaultModel: AIModel { models.first! }
}

/// A model offered by a provider.
struct AIModel: Identifiable, Hashable {
    let id: String      // The model ID sent in requests.
    let hint: String    // Short cost/quality hint.

    var title: String { id }
}
