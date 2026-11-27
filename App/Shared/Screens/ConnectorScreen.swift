import LectoraCore
import SwiftUI

/// Ajustes › Conexiones › Readwise o Hardcover: conectar con tu llave, ver cómo
/// va y decidir qué viaja.
struct ConnectorScreen: View {
    let connector: Connector
    @ObservedObject private var store = ConnectorsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var connecting = false
    @State private var errorMessage: String?
    @State private var confirmingDisconnect = false
    @State private var exported: URL?
    @AppStorage(ConnectorKeys.readwiseSend) private var readwiseSend = true
    @AppStorage(ConnectorKeys.readwiseReceive) private var readwiseReceive = true
    @AppStorage(ConnectorKeys.hardcoverFinish) private var hardcoverFinish = true

    private var connected: Bool { store.isConnected(connector) }

    var body: some View {
        Form {
            Section {
                Text(connector.explanation)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if connected { connectedSections } else { connectSection }
        }
        .formScreen()
        .inlineTitle(connector.title)
        .errorAlert("No pude conectarme", message: $errorMessage, back: "Volver a la conexión")
        .confirmationDialog("¿Desconectar \(connector.title) de tu Gabinete?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("Desconectar \(connector.title)", role: .destructive) { store.disconnect(connector) }
            Button("Seguir conectado", role: .cancel) {}
        } message: {
            Text("Borro tu llave del Llavero. Lo que ya mandé se queda en \(connector.title) y lo de tu Gabinete se queda aquí.")
        }
    }

    private var connectSection: some View {
        Section {
            SecureField("Pega tu llave", text: $key)
                .textContentType(.password)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            Button {
                connecting = true
                Task {
                    do { try await store.connect(connector, key: key); key = "" }
                    catch { errorMessage = error.localizedDescription }
                    connecting = false
                }
            } label: {
                if connecting { LoadingLine(text: "Conectando con \(connector.title)…") } else { Text("Conectar \(connector.title)") }
            }
            .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || connecting)
        } header: {
            CapsText(text: "Tu llave")
        } footer: {
            Text(connector.keyHelp + " La guardo en tu Llavero de iCloud: la pones una vez y sirve en tu iPhone y tu Mac.")
        }
    }

    @ViewBuilder
    private var connectedSections: some View {
        Section {
            if let name = store.username(connector) {
                LabeledContent("Cuenta", value: "@\(name)")
            }
            LabeledContent("Estado", value: statusText)
            if let last = store.lastSync(connector) {
                LabeledContent("Última vez", value: last.formatted(.relative(presentation: .named).locale(.gabinete)))
            }
            let pending = store.pending(connector)
            if pending > 0 {
                LabeledContent("Por mandar", value: "\(pending)")
            }
            Button("Sincronizar ahora") { Task { await store.sync() } }
                .disabled(store.status[connector] == .syncing)
        } header: {
            CapsText(text: "Estado")
        }
        switch connector {
        case .readwise:
            Section {
                Toggle("Mandar mis subrayados", isOn: $readwiseSend)
                Toggle("Traer los de otras fuentes", isOn: $readwiseReceive)
            } header: {
                CapsText(text: "Qué viaja")
            } footer: {
                Text("Lo que llega de Readwise (Kindle, Apple Books…) aparece en tu Cuaderno; si el libro está en tu biblioteca, con él. Lo que nació en Gabinete no vuelve duplicado.")
            }
            Section {
                Button("Exportar todos mis subrayados (CSV)") {
                    exported = try? store.exportCSV()
                }
                if let exported {
                    ShareLink(item: exported) { Label("Compartir el archivo", systemImage: "square.and.arrow.up") }
                }
            } footer: {
                Text("Salida libre: puedes importar el CSV en Readwise o en cualquier hoja de cálculo.")
            }
        case .hardcover:
            Section {
                Toggle("Marcar «Leído» al terminar", isOn: $hardcoverFinish)
            } header: {
                CapsText(text: "Qué viaja")
            } footer: {
                Text("Tu calificación (las estrellas de la ficha) también viaja. Busco cada libro en Hardcover una vez (por ISBN o título y autor) y su número queda en el catálogo como hardcover:…, también en el OPF.")
            }
        }
        Section {
            Button("Desconectar", role: .destructive) { confirmingDisconnect = true }
        }
    }

    private var statusText: String {
        switch store.status[connector] ?? .off {
        case .off: "Sin conectar"
        case .idle: "Conectado"
        case .syncing: "Sincronizando…"
        case .failed(let message): message
        }
    }
}
