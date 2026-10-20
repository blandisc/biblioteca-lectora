import SwiftUI

/// Los dos estilos en prueba. Se cambian en Cuenta → Apariencia.
enum DesignStyle: String, CaseIterable, Identifiable {
    /// v7: componentes del sistema, tarjetas y vidrio.
    case native
    /// v5: papel, tipografía y casi nada más.
    case editorial

    var id: Self { self }

    var title: String {
        switch self {
        case .native: "Nativo"
        case .editorial: "Editorial"
        }
    }

    var summary: String {
        switch self {
        case .native: "Tarjetas, vidrio y barra de pestañas del sistema."
        case .editorial: "Papel, tipografía y lo mínimo en pantalla."
        }
    }
}

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
    static let style = "appearance.style"
    static let mode = "appearance.mode"
    static let plainHome = "appearance.plainHome"
}

/// Cuenta, conexiones y apariencia. Se abre desde el inicio en los dos estilos.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .native
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @AppStorage(AppearanceKeys.plainHome) private var plainHome = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Estilo", selection: $style) {
                        ForEach(DesignStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Modo", selection: $mode) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if style == .native {
                        Toggle("Inicio sin título ni tarjeta", isOn: $plainHome)
                    }
                } header: {
                    Text("Apariencia")
                } footer: {
                    Text(style.summary)
                }
                Section("Biblioteca") {
                    LabeledContent("iCloud Drive", value: "Próximamente")
                    LabeledContent("Google Drive", value: "Próximamente")
                    LabeledContent("OneDrive", value: "Próximamente")
                }
                Section("Subrayados") {
                    LabeledContent("Readwise", value: "Próximamente")
                }
                Section("Inteligencia") {
                    LabeledContent("En el dispositivo", value: "Apple")
                    LabeledContent("Conector externo", value: "Sin configurar")
                }
            }
            .navigationTitle("Cuenta")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .preferredColorScheme(mode.colorScheme)
    }
}
