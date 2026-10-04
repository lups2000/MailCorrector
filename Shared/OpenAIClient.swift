//
//  OpenAIClient.swift
//  MailCorrector
//
//  A minimal async/await client for the OpenAI Chat Completions API used to
//  proofread email drafts. Shared between the host app and the Mail extension.
//

import Foundation

/// Errors surfaced by `OpenAIClient`.
enum OpenAIClientError: Error, LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case server(status: Int, message: String)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key found. Open MailCorrector and add your key."
        case .emptyInput:
            return "There's no text in the draft to proofread."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .server(let status, let message):
            return "OpenAI request failed (\(status)): \(message)"
        case .decodingFailed:
            return "Could not read the proofread result."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

/// A small client that sends draft text to OpenAI and returns a corrected version.
struct OpenAIClient {

    /// The model used for proofreading.
    let model: String
    /// The endpoint for chat completions.
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    /// The URL session used for requests.
    private let session: URLSession

    init(model: String = "gpt-4o-mini", session: URLSession = .shared) {
        self.model = model
        self.session = session
    }

    /// The system prompt that defines the proofreading behavior.
    private var systemPrompt: String {
        """
        You are a proofreading assistant for email. Correct grammar, spelling, \
        punctuation, and awkward phrasing. Preserve the original meaning, tone, \
        register, and language of the text exactly. Do not translate. Do not add \
        greetings, sign-offs, commentary, or explanations. Return only the \
        corrected text, with no surrounding quotation marks.
        """
    }

    /// Proofreads the given draft text and returns the corrected version.
    ///
    /// - Parameters:
    ///   - text: The draft body to proofread.
    ///   - apiKey: The OpenAI API key.
    /// - Returns: The corrected text.
    func proofread(_ text: String, apiKey: String) async throws -> String {
        let trimmedInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { throw OpenAIClientError.emptyInput }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenAIClientError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let payload = ChatRequest(
            model: model,
            temperature: 0.2,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: trimmedInput)
            ]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenAIClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = Self.extractErrorMessage(from: data) ?? "Request failed."
            throw OpenAIClientError.server(status: http.statusCode, message: message)
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content else {
            throw OpenAIClientError.decodingFailed
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attempts to pull a human-readable message from an OpenAI error payload.
    private static func extractErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable { let message: String }
            let error: APIError
        }
        return try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.message
    }
}

// MARK: - Wire format

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let temperature: Double
    let messages: [Message]
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
