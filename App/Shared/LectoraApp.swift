import SwiftUI

@main
struct LectoraApp: App {
    /// Uno para toda la app: la ventana de la biblioteca, las de los libros y Ajustes en la Mac.
    @StateObject private var model = AppModel()

    init() {
        #if os(iOS)
        // Títulos grandes (Ajustes, formularios) iguales a `Font.screenTitle`: New York 30
        // medium. Antes eran 34 en negrita y se veían distintos al resto de las pantallas.
        let base = UIFont.systemFont(ofSize: 30, weight: .medium)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 30)]
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("Gabinete", id: "biblioteca") {
            RootView(model: model)
                .tint(Theme.accent)
        }
        #if os(macOS)
        .defaultSize(width: Theme.Mac.defaultWindow.width, height: Theme.Mac.defaultWindow.height)
        .windowResizability(.contentMinSize)
        .commands {
            // Archivo › Importar libros… en lugar de «Nueva ventana».
            CommandGroup(replacing: .newItem) {
                Button("Importar libros…") { model.importing = true }
                    .keyboardShortcut("o")
            }
        }
        #endif

        #if os(macOS)
        // En la Mac, cada libro en su ventana: lees con la biblioteca al lado.
        WindowGroup("Libro", id: MacReaderWindow.id, for: OpenBook.self) { $book in
            if let book {
                MacReaderWindow(book: book)
                    .environmentObject(model)
                    .tint(Theme.accent)
            }
        }
        .defaultSize(width: Theme.Size.macReader.width, height: Theme.Size.macReader.height)

        // Gabinete › Ajustes… (⌘,), como toda app de Mac.
        Settings {
            SettingsScreen()
                .environmentObject(model)
                .frame(width: Theme.Mac.settings.width, height: Theme.Mac.settings.height)
                .tint(Theme.accent)
        }
        #endif
    }
}
