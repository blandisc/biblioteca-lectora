import SwiftUI
import UniformTypeIdentifiers

/// Claro, oscuro o lo que diga el sistema.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    /// La hojita de muestra en Ajustes › Apariencia.
    var tone: PageTone {
        switch self {
        case .system: .both
        case .light: .light
        case .dark: .dark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppearanceKeys {
    static let mode = "appearance.mode"
}

enum MetadataKeys {
    /// Clave propia de Google Books (opcional): sin ella solo se usa Open Library.
    static let googleKey = "metadata.googleBooksKey"
}

/// Cuenta, conexiones y apariencia. Se abre desde el Cuaderno.
struct SettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connectors = ConnectorsStore.shared
    @AppStorage(SessionKeys.counter) private var showsCounter = true
    @AppStorage(SessionKeys.summary) private var showsSummary = true
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @AppStorage(MetadataKeys.googleKey) private var googleKey = ""
    @State private var choosingFolder = false
    @State private var migratingCalibre = false
    @State private var chosenFolder: URL?
    @State private var tidyReport: LibraryStore.TidyReport?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Ajustes")
                    // AJ-D: cada grupo en su tarjeta, con el dibujo de lo que controla.
                    SettingsCard(title: "Apariencia") {
                        PageSwatchPicker(options: AppearanceMode.allCases, selection: $mode, title: \.title, tone: \.tone)
                            .padding(.vertical, Theme.Space.l)
                    }
                    SettingsCard(title: "Lectura",
                                 help: "Cada sesión se anota en tu carpeta. Nada sale de tus dispositivos.",
                                 more: "Gabinete anota el tiempo, las palabras y cuánto sostuviste la atención en cada sesión.") {
                        ReadingArt(counter: showsCounter, summary: showsSummary)
                    } content: {
                        ToggleRow(title: "Contador de palabras", isOn: $showsCounter)
                        ToggleRow(title: "Resumen al cerrar el libro", isOn: $showsSummary)
                    }
                    cabinetSection
                    SettingsCard(title: "Datos de los libros",
                                 help: "Portadas, sinopsis y datos salen de Open Library.",
                                 more: "Google Books sin clave casi siempre está saturado; con una clave gratuita de Google Cloud también se busca ahí.") {
                        BookDataArt(source: googleKey.isEmpty ? "Open Library" : "Open Library y Google")
                            .id(Self.bookData)
                    } content: {
                        LinkRow(title: "Fuente", value: googleKey.isEmpty ? "Open Library" : "Open Library y Google Books", chevron: false)
                        FieldRow(title: "Clave de Google Books", prompt: "Agregar", text: $googleKey)
                        NavigationLink {
                            RulesScreen()
                        } label: {
                            LinkRow(title: "Reglas de autores y etiquetas",
                                    value: model.library.rules.isEmpty ? "Ninguna" : "\(model.library.rules.authors.count + model.library.rules.tags.count)")
                        }
                        .buttonStyle(.plain)
                    }
                    SettingsCard(title: "Conexiones",
                                 help: "Cada servicio con tu propia llave, en tu Llavero de iCloud. Gabinete no tiene servidor.") {
                        ConnectionsArt(services: Connector.allCases.map {
                            .init(letter: String($0.title.prefix(1)), name: $0.title, connected: connectors.isConnected($0))
                        })
                    } content: {
                        ForEach(Connector.allCases) { connector in
                            let connected = connectors.isConnected(connector)
                            NavigationLink {
                                ConnectorScreen(connector: connector)
                            } label: {
                                LinkRow(title: connector.title, value: connected ? "Conectado" : "Sin conectar", status: connected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Colophon(version: Self.version)
                        .padding(.top, Theme.Space.xl)
                        .id(Self.colophon)
                }
                .screenContent()
            }
            #if DEBUG
            // Capturas: `-screenshot.demo settingsEnd` abre Ajustes ya al final; `settingsMiddle`, a media hoja;
            // `settingsCabinet`, en Tu Gabinete.
            .task {
                guard let demo = LaunchOptions.demo, demo.hasPrefix("settings") else { return }
                try? await Task.sleep(for: .seconds(1))
                if demo == "settingsEnd" { scroller.scrollTo(Self.colophon, anchor: .bottom) }
                if demo == "settingsMiddle" { scroller.scrollTo(Self.bookData, anchor: .center) }
                if demo == "settingsCabinet" { scroller.scrollTo(Self.cabinet, anchor: .center) }
            }
            #endif
            }
            // Las tarjetas sobre un papel un poco más hondo que el de la app (AJ-8).
            .background(Theme.sunken.ignoresSafeArea())
            .pushedScreen()
            .sheet(isPresented: $migratingCalibre) { CalibreMigrationScreen().environmentObject(model) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): chosenFolder = url
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(dialogTitle, isPresented: Binding(
            get: { chosenFolder != nil },
            set: { if !$0 { chosenFolder = nil } }
        ), titleVisibility: .visible) {
            if let folder = chosenFolder {
                if CabinetLocation.hasLibrary(in: folder) {
                    Button("Abrir la biblioteca que ya está ahí") { run { try model.library.use(cabinet: folder) } }
                } else {
                    Button("Mover mi Gabinete ahí") { run { try await model.library.move(toCabinet: folder) } }
                }
            }
            Button("Dejar el Gabinete donde está", role: .cancel) {}
        } message: {
            Text(dialogMessage)
        }
        .alert("Biblioteca ordenada", isPresented: Binding(
            get: { tidyReport != nil },
            set: { if !$0 { tidyReport = nil } }
        )) {
            Button("Volver a Ajustes", role: .cancel) {}
        } message: {
            Text(tidyReport.map(describe) ?? "")
        }
        .alert("No se pudo", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Volver a Ajustes", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .preferredColorScheme(mode.colorScheme)
    }
}

extension SettingsScreen {
    /// «Tu Gabinete» (TG-1): el dibujo de la carpeta con dónde vive y sus cifras, y lo
    /// que se hace con ella.
    private var cabinetSection: some View {
        SettingsCard(title: "Tu Gabinete",
                     help: "Tus libros con la forma de Calibre y tus notas en Markdown.",
                     more: "Dentro hay dos carpetas: Biblioteca, con la misma forma que una de Calibre (puedes abrirla en Calibre y restaurar la base de datos), y Notas, en Markdown. En iCloud Drive, tu iPhone y tu Mac usan la misma.") {
            CabinetArt(place: place,
                       folder: model.library.isLocal ? "Gabinete" : model.library.cabinet.lastPathComponent,
                       books: model.library.books.count,
                       notes: model.notes.notes.count,
                       moving: model.library.moving || LaunchOptions.cabinet == "moving")
                .id(Self.cabinet)
        } content: {
            if model.library.moving {
                HStack(spacing: Theme.Space.l) {
                    ProgressView()
                    Text("Moviendo tu Gabinete…")
                }
                .frame(minHeight: Theme.Size.row)
            } else {
                Button { choosingFolder = true } label: { LinkRow(title: "Mover a iCloud Drive u otra carpeta") }
                if !model.library.isLocal {
                    Button { model.library.useLocalCabinet() } label: { LinkRow(title: "Volver a la carpeta de este dispositivo") }
                }
            }
            Button { migratingCalibre = true } label: { LinkRow(title: "Traer mi biblioteca de Calibre") }
            Button { tidyReport = model.library.tidy() } label: { LinkRow(title: "Ordenar la biblioteca") }
        }
        .buttonStyle(.plain)
    }

    /// Dónde vive el Gabinete: este dispositivo, iCloud Drive (con sus carpetas de en
    /// medio) u otra carpeta.
    private var place: CabinetArt.Place {
        #if DEBUG
        switch LaunchOptions.cabinet {
        case "icloud": return .iCloud(path: nil)
        case "icloudNested": return .iCloud(path: "Libros › Lectura")
        case "folder": return .folder("Dropbox")
        default: break
        }
        #endif
        if model.library.isLocal {
            #if os(iOS)
            return .device(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")
            #else
            return .device("Mac")
            #endif
        }
        let parent = model.library.cabinet.deletingLastPathComponent().standardizedFileURL.path
        if let range = parent.range(of: "com~apple~CloudDocs") {
            let middle = parent[range.upperBound...].split(separator: "/").joined(separator: " › ")
            return .iCloud(path: middle.isEmpty ? nil : middle)
        }
        if parent.contains("Mobile Documents") { return .iCloud(path: nil) }
        return .folder(model.library.cabinet.deletingLastPathComponent().lastPathComponent)
    }

    private static let colophon = "colofon"
    private static let bookData = "datos"
    private static let cabinet = "gabinete"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var dialogTitle: String {
        guard let folder = chosenFolder else { return "" }
        return CabinetLocation.hasLibrary(in: folder) ? "Ya hay un Gabinete aquí" : "¿Mover tu Gabinete a «\(folder.lastPathComponent)»?"
    }

    private var dialogMessage: String {
        guard let folder = chosenFolder else { return "" }
        if CabinetLocation.hasLibrary(in: folder) {
            return "Se usará esa biblioteca (por ejemplo, la de tu Mac). La de este dispositivo se queda donde está."
        }
        return "Se copian tus libros y notas, se comprueba la copia y luego se borra la de este dispositivo."
    }

    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func describe(_ report: LibraryStore.TidyReport) -> String {
        var lines = ["Revisé \(report.checked.counted("libro", "libros")); \(report.relocated) cambiaron de carpeta para quedar como en Calibre."]
        if !report.missing.isEmpty {
            lines.append("Sin archivo: \(report.missing.prefix(5).joined(separator: ", "))\(report.missing.count > 5 ? "…" : "").")
        }
        if !report.strays.isEmpty {
            lines.append("Carpetas que no están en el catálogo: \(report.strays.count). No borré nada.")
        }
        return lines.joined(separator: "\n")
    }
}
