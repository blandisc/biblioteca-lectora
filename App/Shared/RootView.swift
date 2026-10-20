import SwiftUI

enum AppTab: String, Hashable {
    case reading, library, notebook, search
}

/// Raíz: elige el estilo (Nativo o Editorial) y el modo claro/oscuro.
/// El lector se abre a pantalla completa en los dos.
struct RootView: View {
    @StateObject private var model = AppModel()
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .editorial
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @Namespace private var opening

    var body: some View {
        Group {
            switch style {
            case .native: NativeTabsView()
            case .editorial: EditorialRootView()
            }
        }
        .environmentObject(model)
        .environment(\.bookOpeningNamespace, opening)
        .preferredColorScheme(mode.colorScheme)
        .task {
            await model.seedForScreenshotsIfNeeded()
            if LaunchOptions.opensFirstBook, let first = model.currentBook {
                model.open(first)
            }
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
}

/// Estilo Nativo (v7): barra de pestañas flotante (Leyendo, Biblioteca,
/// Cuaderno) con la búsqueda aparte, como en iOS 26.
private struct NativeTabsView: View {
    @State private var tab: AppTab = AppTab(rawValue: LaunchOptions.tab ?? "") ?? .reading

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            TabView(selection: $tab) {
                Tab("Leyendo", systemImage: "book", value: AppTab.reading) { HomeView() }
                Tab("Biblioteca", systemImage: "books.vertical", value: AppTab.library) { LibraryView() }
                Tab("Cuaderno", systemImage: "note.text", value: AppTab.notebook) { NotebookView() }
                Tab(value: AppTab.search, role: .search) { SearchView() }
            }
        } else {
            TabView(selection: $tab) {
                HomeView()
                    .tabItem { Label("Leyendo", systemImage: "book") }
                    .tag(AppTab.reading)
                LibraryView()
                    .tabItem { Label("Biblioteca", systemImage: "books.vertical") }
                    .tag(AppTab.library)
                NotebookView()
                    .tabItem { Label("Cuaderno", systemImage: "note.text") }
                    .tag(AppTab.notebook)
                SearchView()
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)
            }
        }
    }
}
