import SwiftUI

/// Explizite lokale Freigaben für die zwölf neuen JSON-Kurzbefehle.
/// Bestehende Siri-Kurzbefehle und RED-ID-Anmeldung bleiben unabhängig.
struct RedBitAutomationPermissionsView: View {
    @AppStorage(RedBitLocalAutomationConsent.Scope.status.key) private var status = false
    @AppStorage(RedBitLocalAutomationConsent.Scope.transport.key) private var transport = false
    @AppStorage(RedBitLocalAutomationConsent.Scope.preferences.key) private var preferences = false
    @State private var confirmRevoke = false

    private func binding(_ scope: RedBitLocalAutomationConsent.Scope) -> Binding<Bool> {
        Binding(
            get: {
                switch scope {
                case .status: return status
                case .transport: return transport
                case .preferences: return preferences
                }
            },
            set: { enabled in
                guard scope == .status || !enabled || status else { return }
                RedBitLocalAutomationConsent.set(scope, enabled: enabled)
                // Auch Abhängigkeiten sofort in der Ansicht anzeigen.
                status = RedBitLocalAutomationConsent.isEnabled(.status)
                transport = RedBitLocalAutomationConsent.isEnabled(.transport)
                preferences = RedBitLocalAutomationConsent.isEnabled(.preferences)
            }
        )
    }

    var body: some View {
        Form {
            Section("Local permissions") {
                Toggle("Read playback and queue status", isOn: binding(.status))
                Toggle("Control playback and volume", isOn: binding(.transport))
                    .disabled(!status)
                Toggle("Change audio and shuffle settings", isOn: binding(.preferences))
                    .disabled(!status)
                Text("Status is required for action receipts. Turning it off also revokes both write permissions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Connection") {
                LabeledContent("Apple Shortcuts", value: "Local")
                LabeledContent("Remote MCP", value: "Not connected")
                Text("These permissions apply only to the new local RED Bit automation actions. Apple authentication remains required. Existing Siri actions and RED ID are unchanged.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Revoke all automation permissions", role: .destructive) {
                    confirmRevoke = true
                }
                .disabled(!status && !transport && !preferences)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("RED Automation")
        .confirmationDialog("Revoke all automation permissions?", isPresented: $confirmRevoke, titleVisibility: .visible) {
            Button("Revoke all automation permissions", role: .destructive) {
                RedBitLocalAutomationConsent.revokeAll()
                status = false
                transport = false
                preferences = false
            }
        } message: {
            Text("Future local automation calls will be rejected. Music and accounts are not deleted. Already requested operations may finish.")
        }
    }
}
