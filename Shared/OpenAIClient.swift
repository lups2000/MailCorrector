//
//  OpenAIClient.swift
//  MailCorrector
//
//  A provider-agnostic chat client. It builds the correct request and parses
//  the correct response shape for each supported provider (OpenAI-compatible,
//  Anthropic, Gemini). Shared between the host app and the Mail extension.
//

import Foundation

/// Errors surfaced by `AIClient`.
enum AIClientError: Error, LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case server(status: Int, message: String)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found for this provider. Open MailCorrector and add your key."
        case .emptyInput:
            return "There's no text to process."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .server(let status, let message):
            return "Request failed (\(status)): \(message)"
        case .decodingFailed:
            return "Could not read the model's response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

/// A chat client that targets a specific provider and model.
struct AIClient {

    let provider: Provider
    let model: String
    private let session: URLSession

    init(provider: Provider, model: String, session: URLSession = .shared) {
        self.provider = provider
        self.model = model
        self.session = session
    }

    // MARK: - Public transform entry points

    func transform(_ text: String, action: TextAction, apiKey: String) async throws -> String {
        try await run(text, systemPrompt: action.systemPrompt, apiKey: apiKey)
    }

    func transform(_ text: String, customInstruction: String, apiKey: String) async throws -> String {
        try await run(text, systemPrompt: CustomInstruction.systemPrompt(customInstruction), apiKey: apiKey)
    }

    func transform(_ text: String, language: Language, apiKey: String) async throws -> String {
        try await run(text, systemPrompt: language.systemPrompt, apiKey: apiKey)
    }

    // MARK: - Core

    private func run(_ text: String, systemPrompt: String, apiKey: String) async throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIClientError.emptyInput }

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIClientError.missingAPIKey }

        let request = try buildRequest(systemPrompt: systemPrompt, userText: input, apiKey: key)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIClientError.server(status: http.statusCode,
                                       message: Self.errorMessage(from: data) ?? "Request failed.")
        }

        guard let text = parseResponse(data) else {
            throw AIClientError.decodingFailed
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Per-provider request building

    private func buildRequest(systemPrompt: String, userText: String, apiKey: String) throws -> URLRequest {
        switch provider {
        case .openAI, .openRouter:
            return try openAICompatibleRequest(base: provider == .openAI
                                                ? "https://api.openai.com/v1/chat/completions"
                                                : "https://openrouter.ai/api/v1/chat/completions",
                                               systemPrompt: systemPrompt, userText: userText, apiKey: apiKey)
        case .anthropic:
            return try anthropicRequest(systemPrompt: systemPrompt, userText: userText, apiKey: apiKey)
        case .gemini:
            return try geminiRequest(systemPrompt: systemPrompt, userText: userText, apiKey: apiKey)
        }
    }

    private func openAICompatibleRequest(base: String, systemPrompt: String, userText: String, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: URL(string: base)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func anthropicRequest(systemPrompt: String, userText: String, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userText]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func geminiRequest(systemPrompt: String, userText: String, apiKey: String) throws -> URLRequest {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": userText]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Per-provider response parsing

    private func parseResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        switch provider {
        case .openAI, .openRouter:
            // choices[0].message.content
            let choices = json["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            return message?["content"] as? String
        case .anthropic:
            // content[0].text
            let content = json["content"] as? [[String: Any]]
            return content?.first?["text"] as? String
        case .gemini:
            // candidates[0].content.parts[0].text
            let candidates = json["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            return parts?.first?["text"] as? String
        }
    }

    /// Best-effort extraction of a human-readable error message from any provider.
    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // OpenAI / Anthropic style: { "error": { "message": "..." } }
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String { return message }
            if let type = error["type"] as? String { return type }
        }
        return nil
    }
}
