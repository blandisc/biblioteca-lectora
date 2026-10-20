import SwiftUI

enum AppTab: Hashable {
    case reading, library, notebook, search
}

/// Raíz: barra de pestañas flotante (Leyendo, Biblioteca, Cuaderno) con la
/// búsqueda aparte, como en iOS 26. El lector se abre a pantalla completa.
struct RootView: View {
    @StateObject private var model = AppModel()
    @State private var tab: AppTab = .reading

    var body: some View {
        tabs
            .environmentObject(model)
            .fileImporter(isPresented: $model.importing, allowedContentTypes: LocalBooks.readableTypes) { result in
                model.finishImport(result)
            }
            .alert("No se pudo importar", isPresented: Binding(
                get: { model.importError != nil },
                set: { if !$0 { model.importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.importError ?? "")
            }
            #if os(iOS)
            .fullScreenCover(item: $model.openBook) { book in
                ReaderView(bookFile: book.url)
            }
            #else
            .sheet(item: $model.openBook) { book in
                ReaderView(bookFile: book.url)
                    .frame(minWidth: 720, minHeight: 820)
            }
            #endif
    }

    @ViewBuilder
    private var tabs: some View {
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
