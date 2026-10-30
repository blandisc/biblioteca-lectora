import SwiftUI

/// Raíz: dock nativo (Mesa, Biblioteca, Cuaderno) con la búsqueda aparte, el
/// mini reproductor encima y el lector a pantalla completa.
struct RootView: View {
    enum Place: String, Hashable {
        case desk, library, notebook, search
    }

    @StateObject private var model = AppModel()
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
                // Los que se importaron sin internet se buscan ahora.
                await model.library.retryPendingLookups()
            }
            // Al volver a la app: lo que cambió en tus otros dispositivos (iCloud).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.library.refreshFromCloud() }
            }
            .fileImporter(isPresented: $model.importing, allowedContentTypes: LibraryStore.importableTypes,
                          allowsMultipleSelection: true) { result in
                model.finishImport(result)
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
                ReaderView(bookFile: book.url, bookID: book.bookID)
                    .bookOpeningDestination(in: opening, enabled: book.fromCover)
            }
            #else
            .sheet(item: $model.openBook) { book in
                ReaderView(bookFile: book.url, bookID: book.bookID)
                    .frame(minWidth: 720, minHeight: 820)
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
