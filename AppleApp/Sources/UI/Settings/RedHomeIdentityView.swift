import SwiftUI
import RedNativeIdentity
import CoreGraphics

/// Private RED identity is deliberately separate from the music provider account.
/// No automatic network calls, uploads or data sharing.
struct RedHomeIdentityView: View {
    // Injiziert aus der App, damit die SDK-Ansicht eigenständig prüfbar bleibt.
    var readStatus: (@MainActor @Sendable () throws -> String)? = nil
    var canReadStatus: (@MainActor @Sendable () -> Bool)? = nil
    var canTransport: (@MainActor @Sendable () -> Bool)? = nil
    var executeTransport: (@MainActor @Sendable (RedBitServerCommand) throws -> RedBitServerOutcome)? = nil
    @State private var transportJob: RedBitTransportJob?
    @State private var transportTask: Task<Void, Never>?
    @State private var transportStatus: LocalizedStringKey = "Noch nicht geprüft."
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var confirmReadJob = false
    @State private var readTask: Task<Void, Never>?
    @State private var readJobStatus: LocalizedStringKey = "Noch nicht geprüft."
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
            Section("Server-Statusauftrag") {
                Button("Einmaligen Statusauftrag beantworten") { confirmReadJob = true }
                    .disabled(busy || savedOrigin.isEmpty || proof != nil || readStatus == nil || canReadStatus?() != true || scenePhase != .active)
                Text(readJobStatus).font(.footnote).foregroundStyle(.secondary)
                Text("Nur mit lokaler Statusfreigabe. Übermittelt bei einem offenen Auftrag einmalig Wiedergabezustand, Position und Dauer sowie begrenzte Statusmerkmale an deinen privaten Server. Keine Titel oder Kontodaten. Keine Musiksteuerung.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Server-Musiksteuerung") {
                Button("Musikauftrag abrufen") { claimTransportJob() }
                    .disabled(busy || savedOrigin.isEmpty || proof != nil || transportJob != nil || executeTransport == nil || canTransport?() != true || scenePhase != .active)
                if let job = transportJob {
                    LabeledContent("Befehl", value: transportLabel(job.command))
                    Text(job.expiryDate, format: .dateTime.hour().minute().second())
                    Button("Diesen Befehl ausführen") { finishTransportJob(confirmed: true) }
                        .disabled(busy || canTransport?() != true || scenePhase != .active)
                    Button("Auftrag ablehnen", role: .cancel) { finishTransportJob(confirmed: false) }
                        .disabled(busy)
                }
                Text(transportStatus).font(.footnote).foregroundStyle(.secondary)
                Text("Nur manuelle Einzelaufträge mit lokaler Freigabe. Keine Hintergrundsteuerung und keine automatische Wiederholung.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("RED Home Server")
        .onAppear { visible = true; if origin.isEmpty { origin = savedOrigin } }
        .onDisappear {
            visible = false
            readTask?.cancel(); transportTask?.cancel(); transportJob = nil
            clearProof(); permission = nil; permissionStatus = "Noch nicht geprüft."
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { readTask?.cancel(); transportTask?.cancel(); transportJob = nil }
        }
        .confirmationDialog("Status einmalig an den privaten Server senden?", isPresented: $confirmReadJob, titleVisibility: .visible) {
            Button("Auftrag prüfen und beantworten") { respondToReadJob() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Nur wenn ein gültiger, bestätigter Serverauftrag vorliegt. Keine automatische Wiederholung.")
        }
        .confirmationDialog("RED ID trennen?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Trennen", role: .destructive) {
                run { client in
                    do {
                        try await client.logout()
                        identity = nil
                        transportJob = nil
                        clearProof()
                        savedOrigin = ""
                        origin = ""
                        self.client = nil
                        status = "RED ID getrennt."
                    } catch {
                        identity = nil
                        transportJob = nil
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
                    identity = nil; transportJob = nil; clearProof(); savedOrigin = ""; origin = ""; client = nil
                    permission = nil; permissionStatus = "Noch nicht geprüft."
                    status = "Lokaler Zugang gelöscht. Serverzugang separat in RED ION widerrufen."
                } catch { status = "Lokale Zugangsdaten konnten nicht gelöscht werden." }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Dies widerruft den Serverzugang nicht. Widerrufe RED BIT zuerst in RED ION, falls erreichbar.") }
    }
    @MainActor
    private func respondToReadJob() {
        guard !busy, visible, scenePhase == .active, canReadStatus?() == true, let readStatus else { return }
        busy = true
        permission = nil
        permissionStatus = "Noch nicht geprüft."
        readJobStatus = "Statusauftrag wird geprüft."
        readTask = Task { @MainActor in
            defer { busy = false; readTask = nil }
            do {
                let client = try getClient()
                let sent = try await client.respondToRedBitReadJob {
                    try Task.checkCancellation()
                    guard visible, scenePhase == .active, canReadStatus?() == true else { throw CancellationError() }
                    return try readStatus()
                }
                readJobStatus = sent ? "Statusantwort vom Server bestätigt." : "Kein offener Statusauftrag."
            } catch {
                // Auch bei Cancellation kann eine bereits gesendete Antwort
                // angekommen sein; kein automatischer erneuter Versuch.
                readJobStatus = "Statusantwort nicht bestätigt. Keine automatische Wiederholung."
            }
        }
    }
    private func transportLabel(_ command: RedBitServerCommand) -> String {
        switch command {
        case .play: return "Play – Wiedergabe starten"
        case .pause: return "Pause – Wiedergabe pausieren"
        case .next: return "Next – Nächster Titel"
        case .previous: return "Previous – Vorheriger Titel"
        }
    }
    @MainActor
    private func claimTransportJob() {
        guard !busy, visible, scenePhase == .active, transportJob == nil, canTransport?() == true else { return }
        busy = true
        transportStatus = "Musikauftrag wird geprüft."
        transportTask = Task { @MainActor in
            defer { busy = false; transportTask = nil }
            do {
                let job = try await getClient().claimRedBitTransportJob()
                try Task.checkCancellation()
                guard visible, scenePhase == .active, canTransport?() == true else { throw CancellationError() }
                transportJob = job
                transportStatus = job == nil ? "Kein offener Musikauftrag." : "Konkreten Befehl prüfen und bestätigen."
            } catch {
                transportStatus = "Abruf nicht bestätigt. Keine automatische Wiederholung."
            }
        }
    }
    @MainActor
    private func finishTransportJob(confirmed: Bool) {
        guard !busy, visible, scenePhase == .active, let job = transportJob, let executeTransport,
              !confirmed || canTransport?() == true else { return }
        transportJob = nil
        busy = true
        transportTask = Task { @MainActor in
            defer { busy = false; transportTask = nil }
            do {
                let outcome = try await getClient().finishRedBitTransportJob(job, confirmed: confirmed) { command, deadline in
                    try Task.checkCancellation()
                    guard visible, scenePhase == .active, canTransport?() == true, deadline > Date()
                    else { throw CancellationError() }
                    return try executeTransport(command)
                }
                switch outcome {
                case .executed: transportStatus = "Befehl angefordert, Serverquittung erhalten."
                case .declined: transportStatus = "Auftrag abgelehnt."
                case .failed: transportStatus = "Befehl nicht verfügbar oder gesperrt."
                }
            } catch {
                transportStatus = "Ausgang nicht bestätigt. Wiedergabe prüfen; nicht automatisch wiederholen."
            }
        }
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
