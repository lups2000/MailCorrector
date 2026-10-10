//
//  ReviewView.swift
//  MailCorrectorExtension
//
//  The SwiftUI UI shown in the Mail compose popover. It transforms the email
//  text the user copied to the clipboard (proofread, rewrite in a tone, make
//  concise/verbose, or a custom instruction) and lets them review and copy
//  the result.
//

import SwiftUI
import AppKit
import Observation

/// The phases of the transformation flow.
enum ReviewPhase: Equatable {
    case idle
    case loading
    case result(text: String)
    case failure(message: String)
}

/// Drives the transformation flow for `ReviewView`.
@MainActor
@Observable
final class ReviewViewModel {

    private(set) var phase: ReviewPhase = .idle
    private(set) var didCopy = false

    /// The custom free-form instruction entered by the user.
    var customInstruction: String = ""

    /// The editable text to transform, seeded from the clipboard.
    var inputText: String

    private let preferences = Preferences()

    /// Remembers the last-run request so "Redo" can repeat it.
    private var lastRequest: Request?

    private enum Request {
        case action(TextAction)
        case custom(String)
        case translate(Language)
    }

    init(inputText: String) {
        self.inputText = inputText
    }

    /// Whether there is any text to work with.
    var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether a custom instruction has been entered.
    var hasCustomInstruction: Bool {
        !customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The display name of the currently selected provider.
    var providerName: String {
        preferences.provider.title
    }

    /// Replaces the input text with the current clipboard contents.
    func loadFromClipboard() {
        inputText = NSPasteboard.general.string(forType: .string) ?? ""
    }

    // MARK: - Running transformations

    func run(_ action: TextAction) async {
        await perform(.action(action))
    }

    func runCustom() async {
        let instruction = customInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        await perform(.custom(instruction))
    }

    func translate(to language: Language) async {
        await perform(.translate(language))
    }

    /// Repeats the most recent request.
    func redo() async {
        guard let lastRequest else { return }
        await perform(lastRequest)
    }

    private func perform(_ request: Request) async {
        didCopy = false
        lastRequest = request
        phase = .loading
        do {
            // Resolve the selected provider, its model, and its API key.
            let provider = preferences.provider
            let model = preferences.modelID(for: provider)
            let keychain = KeychainStore(provider: provider)
            guard let key = try keychain.read(), !key.isEmpty else {
                phase = .failure(message: "No API key found for \(provider.title). Open MailCorrector and add it.")
                return
            }
            let client = AIClient(provider: provider, model: model)
            let result: String
            switch request {
            case .action(let action):
                result = try await client.transform(inputText, action: action, apiKey: key)
            case .custom(let instruction):
                result = try await client.transform(inputText, customInstruction: instruction, apiKey: key)
            case .translate(let language):
                result = try await client.transform(inputText, language: language, apiKey: key)
            }
            phase = .result(text: result)
        } catch {
            phase = .failure(message: error.localizedDescription)
        }
    }

    /// Copies the result to the general pasteboard.
    func copyResult(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopy = true
    }
}

struct ReviewView: View {

    @State var model: ReviewViewModel
    @State private var showLanguages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            content

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 360, minHeight: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("MailCorrector", systemImage: "text.badge.checkmark")
                .font(.headline)
            Spacer()
            if case .result = model.phase {
                Button {
                    Task { await model.redo() }
                } label: {
                    Label("Redo", systemImage: "arrow.clockwise")
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
        case .result(let text):
            resultView(text: text)
        case .failure(let message):
            failureView(message: message)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 14) {
            inputSection
            actionButtons
            customSection
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Text to improve", systemImage: "doc.plaintext")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    model.loadFromClipboard()
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Replace with the current clipboard contents")
            }

            TextEditor(text: $model.inputText)
                .font(.callout)
                .frame(height: 90)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if !model.hasText {
                        Text("Copy your draft (⌘A, ⌘C) and tap Paste, or type here.")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var actionButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)],
                  spacing: 8) {
            ForEach(TextAction.allCases) { action in
                Button {
                    Task { await model.run(action) }
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(action.tint)
            }

            // Translate as the final grid cell — a plain button identical to
            // the others that opens a language popover.
            Button {
                showLanguages = true
            } label: {
                Label("Translate", systemImage: "globe")
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.green)
            .popover(isPresented: $showLanguages, arrowEdge: .bottom) {
                languagePicker
            }
        }
        .disabled(!model.hasText)
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Translate to")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(Language.allCases) { language in
                Button {
                    showLanguages = false
                    Task { await model.translate(to: language) }
                } label: {
                    HStack(spacing: 10) {
                        Text(language.flag)
                        Text(language.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
        }
        .frame(width: 200)
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "or" divider between presets and custom input.
            HStack(spacing: 8) {
                Rectangle().fill(.quaternary).frame(height: 1)
                Text("or")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Rectangle().fill(.quaternary).frame(height: 1)
            }
            .padding(.vertical, 2)

            Label("Describe a change", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField("e.g. make it more apologetic", text: $model.customInstruction)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit { Task { await model.runCustom() } }

                Button {
                    Task { await model.runCustom() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(model.hasCustomInstruction && model.hasText ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!model.hasCustomInstruction || !model.hasText)
                .help("Apply custom instruction")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Contacting \(model.providerName)…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }

    // MARK: - Result

    private func resultView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledBox(title: "ORIGINAL", text: model.inputText, prominent: false)
            labeledBox(title: "RESULT", text: text, prominent: true)

            Button {
                model.copyResult(text)
            } label: {
                Label(model.didCopy ? "Copied" : "Copy result",
                      systemImage: model.didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("Paste it over your draft to apply the changes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Failure

    private func failureView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                Task { await model.redo() }
            } label: {
                Text("Try again")
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
            .frame(maxHeight: prominent ? 150 : 80)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(prominent ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.08))
            )
        }
    }
}

#Preview("Idle") {
    ReviewView(model: ReviewViewModel(inputText: "Hi johnn, i hope your doing good."))
        .frame(width: 360, height: 460)
}
