//
//  TextAction.swift
//  MailCorrector
//
//  Defines the transformations the user can apply to email text, each with
//  its own system prompt. Shared between the host app and the Mail extension.
//

import Foundation
import SwiftUI

/// A transformation that can be applied to a piece of email text.
enum TextAction: Hashable, Identifiable, CaseIterable {
    case proofread
    case professional
    case friendly
    case colloquial
    case concise
    case verbose

    var id: Self { self }

    /// Short title for buttons and menus.
    var title: String {
        switch self {
        case .proofread:    return "Proofread"
        case .professional: return "Professional"
        case .friendly:     return "Friendly"
        case .colloquial:   return "Casual"
        case .concise:      return "Concise"
        case .verbose:      return "Expand"
        }
    }

    /// SF Symbol used to represent the action.
    var systemImage: String {
        switch self {
        case .proofread:    return "text.badge.checkmark"
        case .professional: return "briefcase"
        case .friendly:     return "face.smiling"
        case .colloquial:   return "bubble.left.and.bubble.right"
        case .concise:      return "arrow.down.right.and.arrow.up.left"
        case .verbose:      return "arrow.up.left.and.arrow.down.right"
        }
    }

    /// Accent color used to tint the action's button.
    var tint: Color {
        switch self {
        case .proofread:    return .blue
        case .professional: return .indigo
        case .friendly:     return .orange
        case .colloquial:   return .pink
        case .concise:      return .teal
        case .verbose:      return .purple
        }
    }

    /// Sampling temperature. Proofreading stays low/deterministic; rewrites
    /// get a little more freedom.
    var temperature: Double {
        switch self {
        case .proofread: return 0.2
        default:         return 0.4
        }
    }

    /// The system prompt that defines the behavior for this action.
    ///
    /// All actions preserve the core message, language, and factual content,
    /// and return only the transformed text with no commentary.
    var systemPrompt: String {
        let common = "Preserve the original meaning, facts, and language. Do not translate. "
            + "Do not add explanations, commentary, or surrounding quotation marks. "
            + "Return only the resulting email text."

        switch self {
        case .proofread:
            return "You are a proofreading assistant for email. Correct grammar, spelling, "
                + "punctuation, and awkward phrasing while keeping the tone and register "
                + "exactly as they are. " + common
        case .professional:
            return "You are an editor for email. Rewrite the text in a polished, professional "
                + "tone suitable for business correspondence, while keeping the core message. "
                + common
        case .friendly:
            return "You are an editor for email. Rewrite the text in a warm, friendly, and "
                + "approachable tone, while keeping the core message. " + common
        case .colloquial:
            return "You are an editor for email. Rewrite the text in a relaxed, casual, "
                + "conversational tone, while keeping the core message. " + common
        case .concise:
            return "You are an editor for email. Rewrite the text to be clearer and more "
                + "concise, removing redundancy while keeping all essential information and "
                + "the overall tone. " + common
        case .verbose:
            return "You are an editor for email. Expand the text with a little more detail and "
                + "smoother phrasing where helpful, without inventing new facts and keeping the "
                + "overall tone. " + common
        }
    }

    /// Actions surfaced as primary buttons in the compact popover.
    static let primary: [TextAction] = [.proofread, .professional, .concise]

    /// Actions shown in the overflow menu.
    static let overflow: [TextAction] = [.friendly, .colloquial, .verbose]
}

/// Builds the system prompt for a free-form custom instruction.
enum CustomInstruction {
    static func systemPrompt(_ instruction: String) -> String {
        "You are an email editing assistant. Apply the user's instruction to the email "
            + "text that follows. Preserve the original language and any factual content "
            + "unless the instruction says otherwise. Do not add explanations, commentary, "
            + "or surrounding quotation marks. Return only the resulting email text.\n\n"
            + "Instruction: \(instruction)"
    }
}

/// A target language the user can translate an email into.
enum Language: String, CaseIterable, Identifiable {
    case english   = "English"
    case spanish   = "Spanish"
    case french    = "French"
    case german    = "German"
    case italian   = "Italian"
    case portuguese = "Portuguese"
    case dutch     = "Dutch"
    case chinese   = "Chinese (Simplified)"
    case japanese  = "Japanese"

    var id: Self { self }

    /// Display name shown in the picker.
    var title: String { rawValue }

    /// A flag emoji to decorate the menu item.
    var flag: String {
        switch self {
        case .english:    return "🇬🇧"
        case .spanish:    return "🇪🇸"
        case .french:     return "🇫🇷"
        case .german:     return "🇩🇪"
        case .italian:    return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .dutch:      return "🇳🇱"
        case .chinese:    return "🇨🇳"
        case .japanese:   return "🇯🇵"
        }
    }

    /// The system prompt for translating into this language.
    var systemPrompt: String {
        "You are a translation assistant for email. Translate the following email text "
            + "into \(rawValue). Preserve the meaning, tone, register, formatting, and any "
            + "names or factual content. Do not add explanations, commentary, or surrounding "
            + "quotation marks. Return only the translated email text."
    }
}
