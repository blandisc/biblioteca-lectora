import SwiftUI

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
                    LabeledContent("Carpeta", value: "En este iPhone")
                    LabeledContent("Libros", value: "\(model.library.books.count)")
                } header: {
                    Text("Biblioteca")
                } footer: {
                    Text("La carpeta tiene la misma forma que una biblioteca de Calibre: puedes abrirla en Calibre y restaurar la base de datos.")
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
        .preferredColorScheme(mode.colorScheme)
    }
}
