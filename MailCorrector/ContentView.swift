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
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var hasExistingKey = false

    private let keychain = KeychainStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                apiKeySection
                instructionsSection
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(minWidth: 480, minHeight: 460)
        .onAppear(perform: loadExistingKey)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("MailCorrector", systemImage: "text.badge.checkmark")
                .font(.largeTitle.bold())
            Text("AI proofreading for Apple Mail.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OpenAI API Key")
                .font(.headline)

            Text("Your key is stored securely in the macOS Keychain and shared with the Mail extension.")
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("sk-…", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Save", action: saveKey)
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasExistingKey {
                    Button("Remove", role: .destructive, action: removeKey)
                        .buttonStyle(.bordered)
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(isError ? .red : .green)
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to enable")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Open Mail ▸ Settings ▸ Extensions.")
                instructionRow(number: 2, text: "Enable “MailCorrector”.")
                instructionRow(number: 3, text: "Restart Mail and open a compose window.")
                instructionRow(number: 4, text: "Click the MailCorrector icon in the compose toolbar to proofread.")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number).")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private func loadExistingKey() {
        if let key = try? keychain.read(), !key.isEmpty {
            apiKey = key
            hasExistingKey = true
        }
    }

    private func saveKey() {
        do {
            try keychain.save(apiKey)
            hasExistingKey = true
            show(message: "Saved.", isError: false)
        } catch {
            show(message: error.localizedDescription, isError: true)
        }
    }

    private func removeKey() {
        do {
            try keychain.delete()
            apiKey = ""
            hasExistingKey = false
            show(message: "Removed.", isError: false)
        } catch {
            show(message: error.localizedDescription, isError: true)
        }
    }

    private func show(message: String, isError: Bool) {
        self.statusMessage = message
        self.isError = isError
    }
}

#Preview {
    ContentView()
}
