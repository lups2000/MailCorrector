//
//  ModelTier.swift
//  MailCorrector
//
//  The specific OpenAI model the user selects for AI requests, ordered from
//  cheapest to highest quality. Shared between the host app and the extension.
//

import Foundation

/// A selectable OpenAI model, ordered from cheapest to highest quality.
///
/// NOTE: Model IDs change over time. Verify these against the current OpenAI
/// model list and update as needed: https://platform.openai.com/docs/models
enum AIModel: String, CaseIterable, Identifiable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt41Mini = "gpt-4.1-mini"
    case gpt4o     = "gpt-4o"
    case gpt41     = "gpt-4.1"

    var id: Self { self }

    /// The default model used when the user hasn't chosen one.
    static let `default`: AIModel = .gpt4oMini

    /// The OpenAI model ID sent in requests.
    var modelID: String { rawValue }

    /// User-facing display name (the real model name).
    var title: String { rawValue }

    /// Short hint about cost/quality shown beside the name.
    var hint: String {
        switch self {
        case .gpt4oMini: return "Cheapest, fast"
        case .gpt41Mini: return "Low cost"
        case .gpt4o:     return "Balanced"
        case .gpt41:     return "Highest quality"
        }
    }
}
