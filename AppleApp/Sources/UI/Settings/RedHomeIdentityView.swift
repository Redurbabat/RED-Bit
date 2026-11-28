import SwiftUI
import RedNativeIdentity
import CoreGraphics

/// Private RED identity is deliberately separate from the music provider account.
/// No automatic network calls, uploads or data sharing.
struct RedHomeIdentityView: View {
    @AppStorage("red.home.identity.origin.v1") private var savedOrigin = ""
    @State private var origin = ""
    @State private var client: RedNativeClient?
    @State private var proof: RedNativeProof?
    @State private var request = ""
    @State private var qr: CGImage?
    @State private var deadline: Date?
    @State private var identity: RedNativeIdentity?
    @State private var busy = false
    @State private var status = "Noch nicht geprüft."
    @State private var confirmDisconnect = false
    @State private var confirmForget = false
    @State private var permission: RedBitServerPermission?
    @State private var permissionStatus: LocalizedStringKey = "Noch nicht geprüft."

    var body: some View {
        Form {
            Section("Privater Server") {
                TextField("https://server.example", text: $origin)
                    .autocorrectionDisabled()
                    .disabled(busy || !savedOrigin.isEmpty || proof != nil)
                Button("Server übernehmen") { configure() }
                    .disabled(busy || origin.isEmpty || !savedOrigin.isEmpty)
                if !savedOrigin.isEmpty {
                    Text(savedOrigin).font(.footnote).foregroundStyle(.secondary)
                }
                Text("Nur deine eigene, vertrauenswürdige HTTPS-Adresse. RED ID ersetzt nicht deine Musik-Anmeldung.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("RED ID") {
                if let identity {
                    LabeledContent("Konto", value: identity.name.isEmpty ? identity.id : identity.name)
                }
                Button("Anmeldung prüfen") {
                    run { client in
                        identity = try await client.identity()
                        status = "RED ID verbunden."
                    }
                }.disabled(busy || savedOrigin.isEmpty || proof != nil)
                Button("Neue Kopplungsanfrage") { createRequest() }
                    .disabled(busy || savedOrigin.isEmpty || proof != nil || identity != nil)
                if let qr {
                    Image(decorative: qr, scale: 1)
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 240)
                        .accessibilityLabel("Öffentliche RED-ID-Kopplungsanfrage")
                }
                if !request.isEmpty {
                    Text(request).font(.caption.monospaced()).textSelection(.enabled)
                    ShareLink(item: request) { Label("Öffentliche Anfrage teilen", systemImage: "square.and.arrow.up") }
                    Text("Nur mit deinem RED ION vergleichen und bestätigen. Der private Verifier bleibt hier.")
                        .font(.footnote)
                    Button("Freigegebene Anmeldung übernehmen") {
                        guard let proof, let deadline, deadline > Date() else { clearProof(); status = "Anfrage abgelaufen."; return }
                        run { client in
                            try await client.claimLogin(verifier: proof.verifier)
                            clearProof()
                            identity = try await client.identity()
                            status = "RED ID verbunden."
                        }
                    }.disabled(busy)
                    Button("Kopplung abbrechen", role: .cancel) { clearProof() }.disabled(busy)
                }
                Button("RED ID trennen", role: .destructive) { confirmDisconnect = true }
                    .disabled(busy || savedOrigin.isEmpty)
                Button("Server lokal vergessen", role: .destructive) { confirmForget = true }
                    .disabled(busy || savedOrigin.isEmpty)
                if busy { ProgressView() }
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Server-Lesefreigabe") {
                Button("Lesefreigabe prüfen") {
                    run { client in
                        do {
                            permission = try await client.redBitPermission()
                            permissionStatus = "Lesefreigabe beim letzten Abruf bestätigt."
                        } catch RedNativeError.http(403) {
                            permissionStatus = "Keine gültige Server-Lesefreigabe."
                        } catch RedNativeError.http(404) {
                            permissionStatus = "Server-Pilot nicht verfügbar."
                        } catch RedNativeError.http(401) {
                            identity = nil
                            permissionStatus = "RED ID nicht autorisiert. Anmeldung prüfen."
                        } catch RedNativeError.notSignedIn {
                            identity = nil
                            permissionStatus = "Nicht angemeldet."
                        } catch {
                            permissionStatus = "Lesefreigabe konnte nicht sicher geprüft werden."
                        }
                    }
                }
                .disabled(busy || savedOrigin.isEmpty || proof != nil)
                Text(permissionStatus).font(.footnote).foregroundStyle(.secondary)
                if let permission {
                    LabeledContent("Spätester Ablauf") {
                        Text(permission.expiryDate, format: .dateTime.day().month().hour().minute())
                    }
                    Text("Nur Momentaufnahme. Die Freigabe kann früher widerrufen werden.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                LabeledContent("Remote MCP", value: "Nicht verbunden")
                Text("Nur die separate Freigabe wird abgefragt. Keine Musiktitel oder Wiedergabedaten werden übertragen. Die lokale Automatisierungsfreigabe bleibt unabhängig.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("RED Home Server")
        .onAppear { if origin.isEmpty { origin = savedOrigin } }
        .onDisappear { clearProof(); permission = nil; permissionStatus = "Noch nicht geprüft." }
        .confirmationDialog("RED ID trennen?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Trennen", role: .destructive) {
                run { client in
                    do {
                        try await client.logout()
                        identity = nil
                        clearProof()
                        savedOrigin = ""
                        origin = ""
                        self.client = nil
                        status = "RED ID getrennt."
                    } catch {
                        identity = nil
                        clearProof()
                        // Native SDK clears local credentials even if remote logout fails.
                        // Keep the origin to allow the owner to verify/retry; no silent success.
                        status = "Abmeldung nicht bestätigt. Widerrufe RED BIT in RED ION und prüfe den Server."
                    }
                }
            }
        } message: { Text("Die Musikanmeldung und lokale Musikdaten bleiben unverändert.") }
        .alert("Server lokal vergessen?", isPresented: $confirmForget) {
            Button("Nur lokal löschen", role: .destructive) {
                do {
                    let scope = try RedNativeClient.credentialScope(origin: savedOrigin, app: "red-bit")
                    try RedKeychainStore().clear(scope: scope)
                    identity = nil; clearProof(); savedOrigin = ""; origin = ""; client = nil
                    permission = nil; permissionStatus = "Noch nicht geprüft."
                    status = "Lokaler Zugang gelöscht. Serverzugang separat in RED ION widerrufen."
                } catch { status = "Lokale Zugangsdaten konnten nicht gelöscht werden." }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Dies widerruft den Serverzugang nicht. Widerrufe RED BIT zuerst in RED ION, falls erreichbar.") }
    }
    private func configure() {
        do {
            let value = origin.trimmingCharacters(in: .whitespacesAndNewlines)
            client = try RedNativeClient(origin: value, app: "red-bit")
            savedOrigin = value
            origin = value
            status = "Adresse gespeichert. Noch keine Verbindung geprüft."
        } catch { status = "Ungültige HTTPS-Adresse." }
    }
    private func getClient() throws -> RedNativeClient {
        if let client { return client }
        let value = try RedNativeClient(origin: savedOrigin, app: "red-bit")
        client = value
        return value
    }
    private func createRequest() {
        do {
            _ = try getClient()
            let next = RedNativeClient.makeProof()
            request = try RedNativeClient.pairingRequest(app: "red-bit", challenge: next.challenge)
            qr = try RedPairQRCode.image(app: "red-bit", challenge: next.challenge)
            proof = next
            deadline = Date().addingTimeInterval(300)
            status = "Anfrage in RED ION freigeben, dann hier übernehmen."
        } catch { clearProof(); status = "Kopplungsanfrage konnte nicht erstellt werden." }
    }
    private func clearProof() {
        proof = nil; request = ""; qr = nil; deadline = nil
    }
    private func run(_ action: @escaping @MainActor (RedNativeClient) async throws -> Void) {
        guard !busy else { return }
        permission = nil
        permissionStatus = "Noch nicht geprüft."
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await action(getClient()) }
            catch RedNativeError.http(401) {
                identity = nil
                status = "Keine gültige Anmeldung oder noch nicht freigegeben. RED ION prüfen."
            } catch RedNativeError.notSignedIn {
                identity = nil
                status = "Nicht angemeldet."
            } catch {
                status = "Verbindung oder sichere Speicherung fehlgeschlagen. Adresse und RED ION prüfen."
            }
        }
    }
}
