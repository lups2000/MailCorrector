//
//  ReviewView.swift
//  MailCorrectorExtension
//
//  The SwiftUI UI shown in the Mail compose popover. It proofreads the draft
//  via OpenAI and lets the user review and copy the corrected text.
//

import SwiftUI
import AppKit
import Observation

/// The phases of the proofreading flow.
enum ReviewPhase: Equatable {
    case idle
    case loading
    case result(corrected: String)
    case failure(message: String)
}

/// Drives the proofreading flow for `ReviewView`.
@MainActor
@Observable
final class ReviewViewModel {

    private(set) var phase: ReviewPhase = .idle
    private(set) var didCopy = false

    let originalText: String

    private let keychain: KeychainStore
    private let client: OpenAIClient

    init(
        originalText: String,
        keychain: KeychainStore = KeychainStore(),
        client: OpenAIClient = OpenAIClient()
    ) {
        self.originalText = originalText
        self.keychain = keychain
        self.client = client
    }

    /// Whether there is any draft text to work with.
    var hasText: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Kicks off a proofreading request.
    func proofread() async {
        didCopy = false
        phase = .loading
        do {
            guard let key = try keychain.read(), !key.isEmpty else {
                phase = .failure(message: OpenAIClientError.missingAPIKey.localizedDescription)
                return
            }
            let corrected = try await client.proofread(originalText, apiKey: key)
            phase = .result(corrected: corrected)
        } catch {
            phase = .failure(message: error.localizedDescription)
        }
    }

    /// Copies the corrected text to the general pasteboard.
    func copyCorrected(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopy = true
    }
}

struct ReviewView: View {

    @State var model: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            content

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 320, minHeight: 380)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Label("MailCorrector", systemImage: "text.badge.checkmark")
                .font(.headline)
            Spacer()
            if case .result = model.phase {
                Button {
                    Task { await model.proofread() }
                } label: {
                    Label("Redo", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            idleView
        case .loading:
            loadingView
        case .result(let corrected):
            resultView(corrected: corrected)
        case .failure(let message):
            failureView(message: message)
        }
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proofread your draft with AI. Grammar, spelling, punctuation, and phrasing are corrected while your meaning, tone, and language stay the same.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Label {
                Text("Select your draft (⌘A) and copy it (⌘C), then tap Proofread.")
            } icon: {
                Image(systemName: "doc.on.clipboard")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button {
                Task { await model.proofread() }
            } label: {
                Text("Proofread copied text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.hasText)

            if !model.hasText {
                Text("Clipboard is empty. Copy your draft text first, then reopen this panel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Contacting OpenAI…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }

    private func resultView(corrected: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledBox(title: "ORIGINAL", text: model.originalText, prominent: false)
            labeledBox(title: "CORRECTED", text: corrected, prominent: true)

            Button {
                model.copyCorrected(corrected)
            } label: {
                Label(model.didCopy ? "Copied" : "Copy corrected text",
                      systemImage: model.didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("Paste it over your draft to apply the changes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func failureView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                Task { await model.proofread() }
            } label: {
                Text("Try again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!model.hasText)
        }
    }

    // MARK: - Helpers

    private func labeledBox(title: String, text: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? "—" : text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: prominent ? 140 : 90)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(prominent ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.08))
            )
        }
    }
}
