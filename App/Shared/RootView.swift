import SwiftUI

/// Raíz: dock nativo (Mesa, Biblioteca, Cuaderno) con la búsqueda aparte, el
/// mini reproductor encima y el lector a pantalla completa.
struct RootView: View {
    enum Place: String, Hashable {
        case desk, library, notebook, search
    }

    @StateObject private var model = AppModel()
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
                if LaunchOptions.opensFirstBook, let first = model.currentBook {
                    model.open(first)
                }
                // Primer arranque, con el Gabinete vacío (no en las capturas automáticas).
                showsWelcome = !welcomeSeen && !LaunchOptions.seed && model.library.books.isEmpty
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
            .alert("Importación", isPresented: Binding(
                get: { model.importReport != nil },
                set: { if !$0 { model.importReport = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.importReport ?? "")
            }
            #if os(iOS)
            .fullScreenCover(item: $model.openBook) { book in
                ReaderView(bookFile: book.url, bookID: book.bookID, startCFI: book.startCFI)
                    .bookOpeningDestination(in: opening, enabled: book.fromCover)
            }
            #else
            .sheet(item: $model.openBook) { book in
                ReaderView(bookFile: book.url, bookID: book.bookID, startCFI: book.startCFI)
                    .frame(minWidth: Theme.Size.macReader.width, minHeight: Theme.Size.macReader.height)
            }
            #endif
    }

    @ViewBuilder
    private var tabs: some View {
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
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(Place.search)
            }
        }
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
        content.sheet(isPresented: $isPresented) { WelcomeScreen().environmentObject(model).frame(minWidth: Theme.Size.macReader.width, minHeight: Theme.Size.macReader.height) }
        #endif
    }
}
