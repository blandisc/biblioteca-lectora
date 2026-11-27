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
                        if library.books.isEmpty, library.waitingForCloud {
                            MacEmptyState(title: EmptyCopy.stillDownloading.title, message: EmptyCopy.stillDownloading.message,
                                          systemImage: "icloud.and.arrow.down")
                        } else if library.books.isEmpty {
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
            // La pista en palabras; los filtros (`autor:`, `serie:`…) se ponen desde su menú.
            .searchable(text: $query, placement: .toolbar, prompt: "Buscar en la biblioteca")
            .inspector(isPresented: $showsInspector) {
                MacBookInspector(library: library, ids: selection.intersection(rows.map(\.id)))
                    .inspectorColumnWidth(min: Theme.Mac.inspectorMin, ideal: Theme.Mac.inspector)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Los filtros de la búsqueda, con su nombre: elegir uno lo escribe en el buscador.
                    Menu {
                        ForEach(LibraryFilterHelp.all, id: \.token) { filter in
                            Button("\(filter.title) (\(filter.token))") { query = LibraryFilterHelp.adding(filter.token, to: query) }
                        }
                    } label: {
                        Label("Buscar por autor, serie, etiqueta…", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .help("Buscar solo en un dato: autor, serie, etiqueta, idioma, editorial, estado, ISBN o título")
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

    /// Las columnas se encogen hasta `Mac.narrowColumn` y cortan con «…»: con su mínimo de antes
    /// la tabla no cabía junto a la ficha, corría de lado y la última se veía cortada sin «…».
    /// Con la ficha abierta no caben todas: van solo título, autor, serie, estado y formato
    /// («Formato» quedaba cortada sin «…» y la tabla corría de lado); el título cede antes que el
    /// autor y la serie, que no bajan de `Mac.nameColumn` (auditoría 3). Son dos tablas y no columnas
    /// escondidas: una columna escondida seguía ocupando su ancho al repartir el de la tabla.
    @ViewBuilder
    private func table(_ rows: [MacBookRow]) -> some View {
        Group {
            if showsInspector {
                Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
                    leadColumns
                    stateColumns
                    extraColumns
                }
            } else {
                Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
                    leadColumns
                    Group {
                        lowColumns
                        stateColumns
                        addedColumn
                    }
                    extraColumns
                }
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

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var leadColumns: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn(Text(Image(systemName: "photo")), value: \MacBookRow.coverKey) { (row: MacBookRow) in
            CoverView(title: row.title, author: row.author, style: row.shelf.cover, image: row.shelf.coverImage)
                .frame(width: Theme.Mac.rowCover.width, height: Theme.Mac.rowCover.height)
        }
        .width(Theme.Mac.coverColumn)
        .customizationID("portada")
        TableColumn("Título", value: \MacBookRow.titleKey) { (row: MacBookRow) in MacCell(text: row.title, role: .title) }
            .width(min: Theme.Mac.column, ideal: Theme.Mac.titleColumn)
            .customizationID("titulo")
        TableColumn("Autor", value: \MacBookRow.authorKey) { (row: MacBookRow) in MacCell(text: row.author) }
            .width(min: Theme.Mac.nameColumn, ideal: Theme.Mac.column)
            .customizationID("autor")
        TableColumn("Serie", value: \MacBookRow.seriesKey) { (row: MacBookRow) in MacCell(text: row.seriesLabel, role: .secondary) }
            .width(min: Theme.Mac.nameColumn, ideal: Theme.Mac.column)
            .customizationID("serie")
    }

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var lowColumns: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn("Etiquetas", value: \MacBookRow.tagsKey) { (row: MacBookRow) in MacCell(text: row.tagsLabel, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("etiquetas")
        TableColumn("Avance", value: \MacBookRow.progress) { (row: MacBookRow) in MacCell(text: row.progressLabel, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.shortColumn)
            .customizationID("avance")
    }

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var stateColumns: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn("Estado", value: \MacBookRow.stateLabel) { (row: MacBookRow) in MacCell(text: row.stateLabel, role: .secondary) }
            .width(Theme.Mac.shortColumn)
            .customizationID("estado")
        TableColumn("Formato", value: \MacBookRow.format) { (row: MacBookRow) in MacCell(text: row.format, role: .secondary) }
            .width(Theme.Mac.shortColumn)
            .customizationID("formato")
    }

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var addedColumn: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn("Agregado", value: \MacBookRow.added) { (row: MacBookRow) in MacCell(text: row.addedLabel, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("agregado")
    }

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var extraColumns: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn("Idioma", value: \MacBookRow.language) { (row: MacBookRow) in MacCell(text: row.language, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.shortColumn)
            .customizationID("idioma")
            .defaultVisibility(.hidden)
        TableColumn("Valoración", value: \MacBookRow.rating) { (row: MacBookRow) in
            MacCell(text: row.stars, role: .secondary).accessibilityLabel(row.starCount.counted("estrella", "estrellas"))
        }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("valoracion")
            .defaultVisibility(.hidden)
        TableColumn("Editorial", value: \MacBookRow.publisherKey) { (row: MacBookRow) in MacCell(text: row.publisher, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("editorial")
            .defaultVisibility(.hidden)
        TableColumn("Publicado", value: \MacBookRow.published) { (row: MacBookRow) in MacCell(text: row.published, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("publicado")
            .defaultVisibility(.hidden)
        TableColumn("ISBN", value: \MacBookRow.isbn) { (row: MacBookRow) in MacCell(text: row.isbn, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: Theme.Mac.column)
            .customizationID("isbn")
            .defaultVisibility(.hidden)
    }

    /// Todos los libros como renglones, con su avance y si les falta portada o esperan revisión
    /// (también los que no encontré en internet: la misma cuenta que «Por revisar» en el iPhone).
    static func rows(library: LibraryStore, shelf: [ShelfBook]) -> [MacBookRow] {
        let byID = Dictionary(shelf.compactMap { item in item.bookID.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        return library.books.compactMap { book in
            byID[book.id].map {
                MacBookRow(book: book, shelf: $0, hasCover: $0.coverImage != nil,
                           inReview: library.reviews[book.id] != nil)
            }
        }
    }

    /// Los filtros que entiende la búsqueda, dichos en palabras para el menú de la barra.
    enum LibraryFilterHelp {
        struct Filter { let title: String; let token: String }
        static let all = [
            Filter(title: "Por autor", token: "autor:"), Filter(title: "Por serie", token: "serie:"),
            Filter(title: "Por etiqueta", token: "etiqueta:"), Filter(title: "Por idioma", token: "idioma:"),
            Filter(title: "Por editorial", token: "editorial:"), Filter(title: "Por estado", token: "estado:"),
            Filter(title: "Por ISBN", token: "isbn:"), Filter(title: "Por título", token: "título:"),
        ]

        /// El filtro al final de lo escrito, separado por un espacio.
        static func adding(_ token: String, to query: String) -> String {
            let base = query.trimmingCharacters(in: .whitespaces)
            return base.isEmpty ? token : "\(base) \(token)"
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
