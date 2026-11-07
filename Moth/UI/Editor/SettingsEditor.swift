//  SettingsEditor.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

/// Each valid timeout joins the draft as it is typed, because a Send button takes no focus from the field, and
/// leaving the field puts back the last valid one.
struct SettingsEditor: View {

    let settings: RequestSettings
    let update: ((inout RequestSettings) -> Void) -> Void

    @State private var timeoutText = ""
    @FocusState private var isTimeoutFocused: Bool

    var body: some View {
        Form {
            LabeledContent("REQUEST_SETTINGS_TIMEOUT") {
                HStack {
                    TextField("REQUEST_SETTINGS_TIMEOUT", text: $timeoutText)
                        .labelsHidden()
                        .frame(width: 80)
                        .focused($isTimeoutFocused)
                        .accessibilityIdentifier("settings.timeout")
                    Text("REQUEST_SETTINGS_SECONDS")
                }
            }

            Toggle("REQUEST_SETTINGS_FOLLOW_REDIRECTS", isOn: binding(\.followsRedirects))
                .accessibilityIdentifier("settings.followRedirects")

            Toggle("REQUEST_SETTINGS_VERIFY_TLS", isOn: binding(\.verifiesTLS))
                .accessibilityIdentifier("settings.verifyTLS")

            if !settings.verifiesTLS {
                Label("REQUEST_SETTINGS_TLS_WARNING", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.tlsWarning")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear(perform: showStoredTimeout)
        .onChange(of: timeoutText) {
            if let timeout = RequestSettings.timeout(fromText: timeoutText), timeout != settings.timeout {
                update { $0.timeout = timeout }
            }
        }
        .onChange(of: settings.timeout) {
            if !isTimeoutFocused {
                showStoredTimeout()
            }
        }
        .onChange(of: isTimeoutFocused) {
            if !isTimeoutFocused {
                showStoredTimeout()
            }
        }
    }

    private func showStoredTimeout() {
        timeoutText = RequestSettings.timeoutText(for: settings.timeout)
    }

    private func binding(_ keyPath: WritableKeyPath<RequestSettings, Bool>) -> Binding<Bool> {
        Binding {
            settings[keyPath: keyPath]
        } set: { value in
            update { $0[keyPath: keyPath] = value }
        }
    }

}

#Preview("Verification off") {
    SettingsEditor(settings: RequestSettings(followsRedirects: false, verifiesTLS: false)) { _ in }
        .padding()
        .frame(width: 480, height: 240)
}
