//
//  ContentView.swift
//  MailCorrector
//
//  Host-app settings: enter and save the OpenAI API key to the shared
//  Keychain, plus instructions for enabling the Mail extension.
//

import SwiftUI

struct ContentView: View {

    @State private var apiKey: String = ""
    @State private var revealKey = false
    @State private var status: SaveStatus = .none
    @State private var hasSavedKey = false
    @State private var selectedModel: AIModel = Preferences().model
    @FocusState private var keyFieldFocused: Bool

    private let keychain = KeychainStore()
    private let preferences = Preferences()

    /// Transient status shown after a save/remove action.
    private enum SaveStatus: Equatable {
        case none
        case saved
        case removed
        case error(String)
    }

    var body: some View {
        Form {
            headerSection
            apiKeySection
            modelSection
            instructionsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 620)
        .onAppear(perform: loadExistingKey)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 52, height: 52)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("MailCorrector")
                        .font(.title2.bold())
                    Text("AI proofreading for Apple Mail")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section {
            // Full-width input field with reveal toggle. Wrapped so the grouped
            // Form doesn't treat leading text as a trailing-aligned label.
            VStack(alignment: .leading, spacing: 6) {
                Text(hasSavedKey ? "Replace your key" : "Paste your key")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Group {
                        if revealKey {
                            TextField(placeholder, text: $apiKey)
                        } else {
                            SecureField(placeholder, text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .focused($keyFieldFocused)
                    .onSubmit(saveKey)

                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(revealKey ? "Hide key" : "Show key")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)

            // Actions + status.
            HStack(spacing: 12) {
                Button("Save", action: saveKey)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isKeyValid)

                if hasSavedKey {
                    Button("Remove", role: .destructive, action: removeKey)
                        .buttonStyle(.bordered)
                }

                Spacer()

                statusView
            }
        } header: {
            Text("OpenAI API Key")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stored securely in your macOS Keychain and shared only with the Mail extension. It never leaves your Mac except in requests to OpenAI.")
                Link("Get an API key at platform.openai.com",
                     destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.footnote)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .none:
            if hasSavedKey {
                Label("Key saved", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .removed:
            Label("Removed", systemImage: "trash")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .lineLimit(2)
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section {
            Picker(selection: $selectedModel) {
                ForEach(AIModel.allCases) { model in
                    Text("\(model.title)  —  \(model.hint)")
                        .tag(model)
                }
            } label: {
                Label("Model", systemImage: "cpu")
            }
            .onChange(of: selectedModel) { _, newValue in
                preferences.model = newValue
            }
        } header: {
            Text("AI Model")
        } footer: {
            Text("Models are listed from cheapest to highest quality. Higher-quality models produce better results but cost more per request.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        Section {
            instructionRow(1, "Open Mail ▸ Settings ▸ Extensions.")
            instructionRow(2, "Turn on \u{201C}MailCorrector\u{201D}.")
            instructionRow(3, "Restart Mail, then open a compose window.")
            instructionRow(4, "Select your draft, press \u{2318}C, then click the MailCorrector button to proofread.")
        } header: {
            Text("Enable in Mail")
        }
    }

    private func instructionRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.tint, in: Circle())
            Text(text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Validation

    /// A light sanity check: non-empty and looks like an OpenAI key.
    private var isKeyValid: Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("sk-") && trimmed.count >= 20
    }

    /// Placeholder text for the key field, reflecting whether a key is stored.
    private var placeholder: String {
        hasSavedKey ? "Enter a new key to replace the saved one" : "sk-proj-…"
    }

    // MARK: - Actions

    private func loadExistingKey() {
        // Detect whether a key is stored, but do not display it. The field
        // stays empty (placeholder visible) so the user can see it clearly and
        // the stored secret is never shown in plain text.
        if let key = try? keychain.read(), !key.isEmpty {
            hasSavedKey = true
        }
    }

    private func saveKey() {
        do {
            try keychain.save(apiKey)
            hasSavedKey = true
            status = .saved
            apiKey = ""           // Clear the field; the key lives in Keychain now.
            revealKey = false
            keyFieldFocused = false
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func removeKey() {
        do {
            try keychain.delete()
            apiKey = ""
            hasSavedKey = false
            status = .removed
            revealKey = false
            keyFieldFocused = false
        } catch {
            status = .error(error.localizedDescription)
        }
    }
}

#Preview {
    ContentView()
}
