//
//  ContentView.swift
//  MailCorrector
//
//  Host-app settings: choose an AI provider and model, store that provider's
//  API key in the shared Keychain, and show how to enable the Mail extension.
//

import SwiftUI

struct ContentView: View {

    @State private var provider: Provider = Preferences().provider
    @State private var selectedModelID: String = ""
    @State private var apiKey: String = ""
    @State private var revealKey = false
    @State private var hasSavedKey = false
    @State private var status: SaveStatus = .none
    @FocusState private var keyFieldFocused: Bool

    private let preferences = Preferences()

    /// Transient status shown after a save/remove action.
    private enum SaveStatus: Equatable {
        case none, saved, removed
        case error(String)
    }

    var body: some View {
        Form {
            headerSection
            providerSection
            apiKeySection
            instructionsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, minHeight: 640)
        .onAppear {
            selectedModelID = preferences.modelID(for: provider)
            refreshKeyState()
        }
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

    // MARK: - Provider & model

    private var providerSection: some View {
        Section {
            Picker(selection: $provider) {
                ForEach(Provider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            } label: {
                Label("Provider", systemImage: "cloud")
            }
            .onChange(of: provider) { _, newValue in
                preferences.provider = newValue
                selectedModelID = preferences.modelID(for: newValue)
                refreshKeyState()
                status = .none
                apiKey = ""
            }

            Picker(selection: $selectedModelID) {
                ForEach(provider.models) { model in
                    Text("\(model.title)  —  \(model.hint)").tag(model.id)
                }
            } label: {
                Label("Model", systemImage: "cpu")
            }
            .onChange(of: selectedModelID) { _, newValue in
                preferences.setModelID(newValue, for: provider)
            }
        } header: {
            Text("Provider & Model")
        } footer: {
            Text("Models are listed from cheapest to highest quality. Each provider uses its own API key, entered below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - API Key (per provider)

    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasSavedKey ? "Replace your \(provider.title) key" : "Paste your \(provider.title) key")
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

            HStack(spacing: 12) {
                Button("Save", action: saveKey)
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasSavedKey {
                    Button("Remove", role: .destructive, action: removeKey)
                        .buttonStyle(.bordered)
                }

                Spacer()
                statusView
            }
        } header: {
            Text("\(provider.title) API Key")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stored securely in your macOS Keychain and shared only with the Mail extension. It never leaves your Mac except in requests to \(provider.title).")
                Link("Get a \(provider.title) API key", destination: provider.keysURL)
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
                    .foregroundStyle(.green).font(.callout)
            }
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.callout)
        case .removed:
            Label("Removed", systemImage: "trash")
                .foregroundStyle(.secondary).font(.callout)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.callout).lineLimit(2)
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

    // MARK: - Helpers

    private var placeholder: String {
        hasSavedKey ? "Enter a new key to replace the saved one" : provider.keyPlaceholder
    }

    private func keychain() -> KeychainStore {
        KeychainStore(provider: provider)
    }

    // MARK: - Actions

    private func refreshKeyState() {
        if let key = try? keychain().read(), !key.isEmpty {
            hasSavedKey = true
        } else {
            hasSavedKey = false
        }
    }

    private func saveKey() {
        do {
            try keychain().save(apiKey)
            hasSavedKey = true
            status = .saved
            apiKey = ""
            revealKey = false
            keyFieldFocused = false
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func removeKey() {
        do {
            try keychain().delete()
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
