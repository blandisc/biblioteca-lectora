import LectoraCore
import SwiftUI

/// Raíz: dock nativo (Mesa, Biblioteca, Cuaderno) con la búsqueda aparte, el
/// mini reproductor encima y el lector a pantalla completa.
struct RootView: View {
    enum Place: String, Hashable {
        case desk, library, notebook, search
    }

    @ObservedObject var model: AppModel
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @ObservedObject private var sessions = SessionStore.shared
    @AppStorage(WelcomeKeys.seen) private var welcomeSeen = false
    /// Se decide al arrancar: la bienvenida no se cierra sola si a media bienvenida llegan libros.
    @State private var showsWelcome = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @Namespace private var opening
    @State private var place: Place = {
        switch LaunchOptions.tab {
        case "library": .library
        case "notebook": .notebook
        case "search": .search
        default: .desk
        }
    }()

    var body: some View {
        tabs
            .modifier(MiniPlayerAccessory(book: model.listening))
            .environmentObject(model)
            .environment(\.bookOpeningNamespace, opening)
            .preferredColorScheme(mode.colorScheme)
            .task {
                await model.seedForScreenshotsIfNeeded()
                if LaunchOptions.opensFirstBook,
                   let first = LaunchOptions.book.flatMap({ title in model.shelf.first { $0.title.contains(title) } }) ?? model.currentBook {
                    model.open(first)
                }
                // Primer arranque, con el Gabinete vacío (no en las capturas automáticas).
                showsWelcome = (!welcomeSeen && !LaunchOptions.seed && model.library.books.isEmpty)
                    || LaunchOptions.screen == "welcome"
                #if DEBUG
                // Capturas: `-screenshot.screen summary` enseña «Sesión terminada» con una sesión de muestra.
                if LaunchOptions.screen == "summary" {
                    let start = Date().addingTimeInterval(-26 * 65)
                    let pages = (0..<26).map { index in
                        PageView(start: start.addingTimeInterval(Double(index) * 65), end: start.addingTimeInterval(Double(index + 1) * 65),
                                 words: 250, fraction: 0.31 + Double(index) * 0.002)
                    }
                    sessions.justFinished = SessionClassifier().session(bookID: model.currentBook?.bookID ?? UUID(), device: AnnotationStore.deviceID, pages: pages)
                }
                #endif
                // Readwise y Hardcover, si están conectados.
                ConnectorsStore.shared.start()
                // Los que se importaron sin internet se buscan ahora.
                await model.library.retryPendingLookups()
            }
            // Al volver a la app: lo que cambió en tus otros dispositivos (iCloud).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.library.refreshFromCloud()
                    model.notes.refreshFromCloud()
                    sessions.refreshFromCloud()
                    ConnectorsStore.shared.start()
                } else if phase == .background {
                    ConnectorsStore.shared.stop()
                }
            }
            .fileImporter(isPresented: $model.importing, allowedContentTypes: LibraryStore.importableTypes,
                          allowsMultipleSelection: true) { result in
                model.finishImport(result)
            }
            // Primer arranque: dónde vive tu Gabinete, tus libros y Readwise.
            .modifier(WelcomeCover(isPresented: $showsWelcome, model: model))
            .onChange(of: welcomeSeen) { _, seen in if seen { showsWelcome = false } }
            // Al cerrar el libro, el resumen de la sesión.
            .sheet(item: $sessions.justFinished) { session in
                SessionSummarySheet(session: session).environmentObject(model)
            }
            .noticeAlert("No añadí todos tus libros", message: $model.importReport, back: "Ver mis libros")
            // Un archivo de `.lectora` que no pude leer: lo digo una vez, en el iPhone y en la Mac.
            .modifier(LibraryNotice(library: model.library))
            #if os(iOS)
            .fullScreenCover(item: $model.openBook) { book in
                ReaderView(bookFile: book.url, bookID: book.bookID, startCFI: book.startCFI)
                    .bookOpeningDestination(in: opening, enabled: book.fromCover)
            }
            #else
            // El libro se abre en su propia ventana (MG-1).
            .onChange(of: model.openBook) { _, book in
                guard let book else { return }
                openWindow(id: MacReaderWindow.id, value: book)
                model.openBook = nil
            }
            #endif
    }

    @ViewBuilder
    private var tabs: some View {
        #if os(macOS)
        // En la Mac, una app de Mac: barra lateral, tabla y ficha (MG-1).
        MacLibraryWindow()
        #else
        if #available(iOS 18.0, macOS 15.0, *) {
            TabView(selection: $place) {
                Tab("Mesa", systemImage: "book", value: Place.desk) { MesaScreen() }
                Tab("Biblioteca", systemImage: "books.vertical", value: Place.library) { LibraryScreen() }
                Tab("Cuaderno", systemImage: "note.text", value: Place.notebook) { NotebookScreen() }
                Tab(value: Place.search, role: .search) { SearchScreen() }
            }
        } else {
            TabView(selection: $place) {
                MesaScreen()
                    .tabItem { Label("Mesa", systemImage: "book") }
                    .tag(Place.desk)
                LibraryScreen()
                    .tabItem { Label("Biblioteca", systemImage: "books.vertical") }
                    .tag(Place.library)
                NotebookScreen()
                    .tabItem { Label("Cuaderno", systemImage: "note.text") }
                    .tag(Place.notebook)
                SearchScreen()
                    .tabItem { Label(SearchWording.title, systemImage: "magnifyingglass") }
                    .tag(Place.search)
            }
        }
        #endif
    }
}

/// Bienvenida a pantalla completa en el iPhone y como hoja en el Mac.
private struct WelcomeCover: ViewModifier {
    @Binding var isPresented: Bool
    let model: AppModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $isPresented) { WelcomeScreen().environmentObject(model) }
        #else
        // Mide lo que mide su paso (`Theme.Mac.welcome` de ancho), sin pasar de la ventana más chica.
        content.sheet(isPresented: $isPresented) { WelcomeScreen().environmentObject(model) }
        #endif
    }
}

/// El aviso de la biblioteca (`LibraryStore.notice`): se observa la biblioteca misma, así el
/// aviso sale en cuanto lo pone, sin esperar a que cambie otra cosa.
private struct LibraryNotice: ViewModifier {
    @ObservedObject var library: LibraryStore

    func body(content: Content) -> some View {
        content.noticeAlert("No pude leer un archivo de tu Gabinete", message: $library.notice, back: "Volver a mi biblioteca")
    }
}
