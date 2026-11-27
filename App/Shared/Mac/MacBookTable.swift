#if os(macOS)
import AppKit
import LectoraCore
import SwiftUI

/// La tabla de la biblioteca (MG-1): ordenas por cualquier columna, eliges qué columnas ver
/// (clic derecho en el encabezado), eliges varios libros y la ficha de la derecha los edita.
/// Arrastrar archivos a la ventana los importa; doble clic abre el libro.
struct MacBookTable: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var library: LibraryStore
    let section: MacSection

    @State private var selection = Set<UUID>()
    @State private var sortOrder = [KeyPathComparator(\MacBookRow.titleKey)]
    @State private var query = ""
    /// «Guardar como estante» con la búsqueda escrita (CB-1).
    @State private var savingShelf: String?
    @AppStorage("mac.ficha") private var showsInspector = true
    @SceneStorage("mac.columnas") private var columns = TableColumnCustomization<MacBookRow>()

    var body: some View {
        let parsed = LibraryQuery(query)
        let rows = Self.rows(library: library, shelf: model.shelf)
            .filter { section.contains($0) && parsed.matches($0.book) }
            .sorted(using: sortOrder)
        table(rows)
            .overlay {
                if rows.isEmpty {
                    if query.isEmpty {
                        ContentUnavailableView("Nada aquí", systemImage: "books.vertical",
                                               description: Text("Arrastra libros a esta ventana para traerlos a tu Gabinete."))
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .navigationTitle(section.title)
            .navigationSubtitle(rows.count.counted("libro", "libros"))
            .searchable(text: $query, placement: .toolbar, prompt: "Buscar · autor: serie: etiqueta: idioma:")
            .inspector(isPresented: $showsInspector) {
                MacBookInspector(library: library, ids: selection.intersection(rows.map(\.id)))
                    .inspectorColumnWidth(min: Theme.Mac.inspectorMin, ideal: Theme.Mac.inspector)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.importing = true } label: { Label("Importar libros", systemImage: "plus") }
                        .help("Importar libros (⌘O)")
                    Button { savingShelf = query } label: { Label("Guardar como estante", systemImage: "rectangle.stack.badge.plus") }
                        .disabled(LibraryQuery(query).isEmpty)
                        .help("Guardar esta búsqueda como un estante que se llena solo")
                    Button { lookUp(selection) } label: { Label("Buscar datos", systemImage: "wand.and.stars") }
                        .disabled(selection.isEmpty)
                        .help("Buscar portada y datos en internet para lo elegido")
                    Button { showsInspector.toggle() } label: { Label("Ficha", systemImage: "sidebar.right") }
                        .keyboardShortcut("i", modifiers: [.command, .option])
                        .help("Mostrar u ocultar la ficha (⌥⌘I)")
                }
            }
            #if DEBUG
            // Capturas: `-screenshot.demo macOne` abre con un libro elegido; `macMany`, con tres.
            .task {
                guard let demo = LaunchOptions.demo, demo.hasPrefix("mac") else { return }
                try? await Task.sleep(for: .seconds(1))
                selection = Set(rows.prefix(demo == "macMany" ? 3 : 1).map(\.id))
            }
            #endif
            .saveShelfAlert(query: $savingShelf) { library.saveShelf($0) }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty else { return false }
                Task { await model.importBooks(urls) }
                return true
            }
    }

    private func table(_ rows: [MacBookRow]) -> some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
            Group {
                TableColumn(Text(Image(systemName: "photo")), value: \MacBookRow.coverKey) { (row: MacBookRow) in
                    CoverView(title: row.title, author: row.author, style: row.shelf.cover, image: row.shelf.coverImage)
                        .frame(width: Theme.Mac.rowCover.width, height: Theme.Mac.rowCover.height)
                }
                .width(Theme.Mac.coverColumn)
                .customizationID("portada")
                TableColumn("Título", value: \MacBookRow.titleKey) { (row: MacBookRow) in Text(row.title) }
                    .width(min: Theme.Mac.titleColumn)
                    .customizationID("titulo")
                TableColumn("Autor", value: \MacBookRow.authorKey) { (row: MacBookRow) in Text(row.author) }
                    .width(min: Theme.Mac.column)
                    .customizationID("autor")
                TableColumn("Serie", value: \MacBookRow.seriesKey) { (row: MacBookRow) in Text(row.seriesLabel) }
                    .width(min: Theme.Mac.column)
                    .customizationID("serie")
                TableColumn("Etiquetas", value: \MacBookRow.tagsKey) { (row: MacBookRow) in Text(row.tagsLabel) }
                    .width(min: Theme.Mac.column)
                    .customizationID("etiquetas")
            }
            Group {
                TableColumn("Avance", value: \MacBookRow.progress) { (row: MacBookRow) in Text(row.progressLabel).monospacedDigit() }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("avance")
                TableColumn("Estado", value: \MacBookRow.stateLabel) { (row: MacBookRow) in Text(row.stateLabel) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("estado")
                TableColumn("Formato", value: \MacBookRow.format) { (row: MacBookRow) in Text(row.format) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("formato")
                TableColumn("Agregado", value: \MacBookRow.added) { (row: MacBookRow) in Text(row.addedLabel) }
                    .width(min: Theme.Mac.column)
                    .customizationID("agregado")
            }
            Group {
                TableColumn("Idioma", value: \MacBookRow.language) { (row: MacBookRow) in Text(row.language) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("idioma")
                    .defaultVisibility(.hidden)
                TableColumn("Valoración", value: \MacBookRow.rating) { (row: MacBookRow) in Text(row.stars) }
                    .width(min: Theme.Mac.column)
                    .customizationID("valoracion")
                    .defaultVisibility(.hidden)
                TableColumn("Editorial", value: \MacBookRow.publisherKey) { (row: MacBookRow) in Text(row.publisher) }
                    .width(min: Theme.Mac.column)
                    .customizationID("editorial")
                    .defaultVisibility(.hidden)
                TableColumn("Publicado", value: \MacBookRow.published) { (row: MacBookRow) in Text(row.published) }
                    .width(min: Theme.Mac.column)
                    .customizationID("publicado")
                    .defaultVisibility(.hidden)
                TableColumn("ISBN", value: \MacBookRow.isbn) { (row: MacBookRow) in Text(row.isbn).monospacedDigit() }
                    .width(min: Theme.Mac.column)
                    .customizationID("isbn")
                    .defaultVisibility(.hidden)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Abrir") { open(ids) }
                .disabled(ids.count != 1)
            Button(ids.count > 1 ? "Buscar datos para los \(ids.count)" : "Buscar datos") { lookUp(ids) }
            Divider()
            Button("Mostrar en el Finder") { reveal(ids) }
        } primaryAction: { ids in
            open(ids)
        }
    }

    /// Todos los libros como renglones, con su avance y si les falta portada o esperan revisión.
    static func rows(library: LibraryStore, shelf: [ShelfBook]) -> [MacBookRow] {
        let byID = Dictionary(shelf.compactMap { item in item.bookID.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        return library.books.compactMap { book in
            byID[book.id].map {
                MacBookRow(book: book, shelf: $0, hasCover: $0.coverImage != nil,
                           inReview: !(library.reviews[book.id] ?? []).isEmpty)
            }
        }
    }

    private func open(_ ids: Set<UUID>) {
        guard ids.count == 1, let id = ids.first, let book = model.shelfBook(id: id.uuidString) else { return }
        model.open(book)
    }

    private func lookUp(_ ids: Set<UUID>) {
        library.lookUpMany(Array(ids))
    }

    private func reveal(_ ids: Set<UUID>) {
        let files = ids.compactMap { library.book(id: $0) }.compactMap(library.fileURL(for:))
        NSWorkspace.shared.activateFileViewerSelecting(files)
    }
}
#endif
