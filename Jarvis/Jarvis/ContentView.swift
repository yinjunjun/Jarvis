import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: DictationController
    @StateObject private var input = AudioInputMonitor()
    @State private var showingKeySettings = false

    private var canRevise: Bool {
        !controller.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !controller.isRevising
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
                Text("Input: \(input.deviceName)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingKeySettings = true
                } label: {
                    Image(systemName: "key")
                }
                .buttonStyle(.borderless)
                .help("Set OpenAI API key")
            }
            .font(.callout)

            if input.builtInUnavailable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Lid is closed — the built-in mic is disabled. Connect an external mic (AirPods, USB, or display mic) to record.")
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(alignment: .top, spacing: 12) {
                // Left column: transcript box with the Record button beneath it.
                VStack(alignment: .leading, spacing: 6) {
                    editor(title: "Transcript", text: $controller.transcribedText)
                    HStack {
                        Button(controller.isRecording ? "Stop" : "Record") {
                            controller.toggleRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(controller.isRecording ? .red : .accentColor)
                        .keyboardShortcut("r", modifiers: .command)
                        Spacer()
                    }
                }

                // Right column: revised box with the Revise button beneath it.
                VStack(alignment: .leading, spacing: 6) {
                    editor(title: "Revised", text: $controller.revisedText)
                    HStack {
                        Button {
                            controller.revise()
                        } label: {
                            if controller.isRevising {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Revise")
                            }
                        }
                        .disabled(!canRevise)
                        .keyboardShortcut("e", modifiers: .command)
                        Spacer()
                    }
                }
            }

            Divider()

            // Panel footer: status on the left, clipboard + clear on the right.
            HStack(spacing: 12) {
                Text(controller.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    controller.copyRevisedToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .disabled(controller.revisedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Clear", role: .destructive) {
                    controller.clear()
                }
                .disabled(controller.transcribedText.isEmpty && controller.revisedText.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 680, minHeight: 380)
        .onAppear { input.start() }
        .onDisappear { input.stop() }
        .sheet(isPresented: $showingKeySettings) { APIKeySettingsView() }
    }

    private func editor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Sheet for pasting the OpenAI API key into the Keychain. The key itself is
/// never shown again or written to disk in the repo.
struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var hasExisting = !(Keychain.openAIKey() ?? "").isEmpty

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI API Key")
                .font(.headline)
            Text(hasExisting
                 ? "A key is saved in your Keychain. Enter a new key to replace it."
                 : "No key saved yet. Paste your OpenAI API key — it's stored in the macOS Keychain, never in the project.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("sk-…", text: $key)
                .textFieldStyle(.roundedBorder)

            HStack {
                if hasExisting {
                    Button("Remove", role: .destructive) {
                        Keychain.setOpenAIKey("")
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    Keychain.setOpenAIKey(key)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
