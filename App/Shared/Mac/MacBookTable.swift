#if os(macOS)
import AppKit
import LectoraCore
import SwiftUI

/// La tabla de la biblioteca (MG-1): ordenas por cualquier columna, eliges qué columnas ver
/// (clic derecho en el encabezado), eliges varios libros y la ficha de la derecha los edita.
/// Arrastrar archivos a la ventana los importa; doble clic abre el libro.
struct MacBookTable: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var library: LibraryStore
    let section: MacSection
    /// Volver a «Todos» desde una sección que no deja nada.
    var showAll: () -> Void = {}

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
                        if library.books.isEmpty {
                            MacEmptyState(title: EmptyCopy.noBooks.title, message: EmptyCopy.noBooks.message)
                        } else {
                            MacEmptyState(title: EmptyCopy.noMatch(section.title).title, message: EmptyCopy.noMatch(section.title).message,
                                          actionTitle: EmptyCopy.showAll, action: showAll)
                        }
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
                    Button { model.importing = true } label: { Label(LibraryAction.addBooks.title, systemImage: LibraryAction.addBooks.symbol) }
                        .help("\(LibraryAction.addBooks.title) (⌘O)")
                    Button { savingShelf = query } label: { Label("Guardar como estante", systemImage: "rectangle.stack.badge.plus") }
                        .disabled(LibraryQuery(query).isEmpty)
                        .help("Guardar esta búsqueda como un estante que se llena solo")
                    Button { lookUp(selection) } label: { Label(LibraryAction.findData(count: selection.count), systemImage: LibraryAction.findData.symbol) }
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
                // `-screenshot.pick Título` elige los libros cuyo título lo contiene; `-screenshot.size 900x600` cambia la ventana.
                if let size = UserDefaults.standard.string(forKey: "screenshot.size")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
                    NSApp.windows.first { $0.isVisible }?.setContentSize(NSSize(width: size[0], height: size[1]))
                }
                if LaunchOptions.screen == "settings" {
                    openSettings()
                }
                if let pick = UserDefaults.standard.string(forKey: "screenshot.pick") {
                    try? await Task.sleep(for: .seconds(1))
                    selection = Set(rows.filter { $0.title.localizedCaseInsensitiveContains(pick) }.map(\.id))
                    return
                }
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
                TableColumn("Título", value: \MacBookRow.titleKey) { (row: MacBookRow) in MacCell(text: row.title, role: .title) }
                    .width(min: Theme.Mac.titleColumn)
                    .customizationID("titulo")
                TableColumn("Autor", value: \MacBookRow.authorKey) { (row: MacBookRow) in MacCell(text: row.author) }
                    .width(min: Theme.Mac.column)
                    .customizationID("autor")
                TableColumn("Serie", value: \MacBookRow.seriesKey) { (row: MacBookRow) in MacCell(text: row.seriesLabel, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("serie")
                TableColumn("Etiquetas", value: \MacBookRow.tagsKey) { (row: MacBookRow) in MacCell(text: row.tagsLabel, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("etiquetas")
            }
            Group {
                TableColumn("Avance", value: \MacBookRow.progress) { (row: MacBookRow) in MacCell(text: row.progressLabel, role: .secondary) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("avance")
                TableColumn("Estado", value: \MacBookRow.stateLabel) { (row: MacBookRow) in MacCell(text: row.stateLabel, role: .secondary) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("estado")
                TableColumn("Formato", value: \MacBookRow.format) { (row: MacBookRow) in MacCell(text: row.format, role: .secondary) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("formato")
                TableColumn("Agregado", value: \MacBookRow.added) { (row: MacBookRow) in MacCell(text: row.addedLabel, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("agregado")
            }
            Group {
                TableColumn("Idioma", value: \MacBookRow.language) { (row: MacBookRow) in MacCell(text: row.language, role: .secondary) }
                    .width(min: Theme.Mac.shortColumn)
                    .customizationID("idioma")
                    .defaultVisibility(.hidden)
                TableColumn("Valoración", value: \MacBookRow.rating) { (row: MacBookRow) in
                    MacCell(text: row.stars, role: .secondary).accessibilityLabel(row.starCount.counted("estrella", "estrellas"))
                }
                    .width(min: Theme.Mac.column)
                    .customizationID("valoracion")
                    .defaultVisibility(.hidden)
                TableColumn("Editorial", value: \MacBookRow.publisherKey) { (row: MacBookRow) in MacCell(text: row.publisher, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("editorial")
                    .defaultVisibility(.hidden)
                TableColumn("Publicado", value: \MacBookRow.published) { (row: MacBookRow) in MacCell(text: row.published, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("publicado")
                    .defaultVisibility(.hidden)
                TableColumn("ISBN", value: \MacBookRow.isbn) { (row: MacBookRow) in MacCell(text: row.isbn, role: .secondary) }
                    .width(min: Theme.Mac.column)
                    .customizationID("isbn")
                    .defaultVisibility(.hidden)
            }
        }
        // De papel (MX-B): la tabla sobre el papel de Gabinete, sin franjas.
        .macPaper()
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Abrir el libro") { open(ids) }
                .disabled(ids.count != 1)
            Button(LibraryAction.findData(count: ids.count)) { lookUp(ids) }
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
