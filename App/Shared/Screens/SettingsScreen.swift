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
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @AppStorage(MetadataKeys.googleKey) private var googleKey = ""
    @State private var choosingFolder = false
    @State private var chosenFolder: URL?
    @State private var tidyReport: LibraryStore.TidyReport?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Apariencia") {
                    Picker("Modo", selection: $mode) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    LabeledContent("Carpeta", value: CabinetLocation.displayName(model.library.cabinet))
                    LabeledContent("Libros", value: "\(model.library.books.count)")
                    if model.library.moving {
                        HStack(spacing: Theme.Space.m) {
                            ProgressView()
                            Text("Moviendo tu Gabinete…")
                        }
                    } else {
                        Button("Elegir carpeta (p. ej. en iCloud Drive)…") { choosingFolder = true }
                        if !model.library.isLocal {
                            Button("Volver a la carpeta de este dispositivo") { model.library.useLocalCabinet() }
                        }
                    }
                    Button("Ordenar la biblioteca") { tidyReport = model.library.tidy() }
                } header: {
                    Text("Gabinete")
                } footer: {
                    Text("Dentro hay dos carpetas: Biblioteca, con la misma forma que una de Calibre (puedes abrirla en Calibre y restaurar la base de datos), y Notas, en Markdown. En iCloud Drive, tu iPhone y tu Mac usan la misma.")
                }
                Section {
                    LabeledContent("Fuente", value: googleKey.isEmpty ? "Open Library" : "Open Library y Google Books")
                    TextField("Clave de Google Books (opcional)", text: $googleKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    NavigationLink {
                        RulesScreen()
                    } label: {
                        LabeledContent("Reglas de autores y etiquetas",
                                       value: model.library.rules.isEmpty ? "Ninguna" : "\(model.library.rules.authors.count + model.library.rules.tags.count)")
                    }
                } header: {
                    Text("Datos de los libros")
                } footer: {
                    Text("Portadas, sinopsis y datos se buscan en Open Library. Google Books sin clave casi siempre está saturado; con una clave gratuita de Google Cloud también se busca ahí.")
                }
                Section("Conexiones") {
                    LabeledContent("iCloud Drive", value: "Próximamente")
                    LabeledContent("Readwise", value: "Próximamente")
                    LabeledContent("IA en la nube", value: "Sin configurar")
                }
            }
            .navigationTitle("Ajustes")
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
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(dialogMessage)
        }
        .alert("Biblioteca ordenada", isPresented: Binding(
            get: { tidyReport != nil },
            set: { if !$0 { tidyReport = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tidyReport.map(describe) ?? "")
        }
        .alert("No se pudo", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .preferredColorScheme(mode.colorScheme)
    }
}

extension SettingsScreen {
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
        var lines = ["Revisé \(report.checked) libros; \(report.relocated) cambiaron de carpeta para quedar como en Calibre."]
        if !report.missing.isEmpty {
            lines.append("Sin archivo: \(report.missing.prefix(5).joined(separator: ", "))\(report.missing.count > 5 ? "…" : "").")
        }
        if !report.strays.isEmpty {
            lines.append("Carpetas que no están en el catálogo: \(report.strays.count). No borré nada.")
        }
        return lines.joined(separator: "\n")
    }
}
