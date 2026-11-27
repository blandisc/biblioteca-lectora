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
    /// Cada tabla guarda sus columnas aparte (auditoría 4): compartidas, la de la ficha abierta
    /// tomaba los anchos de la ancha y lo de las columnas que no tiene se podía perder.
    @SceneStorage("mac.columnas") private var columns = TableColumnCustomization<MacBookRow>()
    @SceneStorage("mac.columnas.ficha") private var narrowColumns = TableColumnCustomization<MacBookRow>()
    /// El ancho que tiene la tabla, en pasos de `Mac.column`: al cambiar (la ventana, la ficha) la
    /// tabla se vuelve a armar y reparte de nuevo sus columnas. Antes se quedaban con los anchos de
    /// la primera vez y «Serie», «Estado» y «Formato» quedaban bajo la ficha (auditoría 4).
    @State private var widthStep = 0
    /// El ancho (en pasos) con que se armó la tabla la última vez, también en otra sesión: si ahora
    /// es más angosta, los anchos guardados de las columnas no caben (auditoría 6, U1).
    @SceneStorage("mac.columnas.paso") private var savedStep = 0
    /// Cómo está armada la tabla: con o sin ficha y con qué ancho ya quieto (auditorías 5 y 6). Se
    /// rearma una sola vez cuando el ancho se queda quieto, también al abrir la ficha (antes se
    /// rearmaba al abrirla y otra vez 350 ms después, al terminar de cambiar el ancho).
    @State private var layout: TableLayoutKey?
    /// Las filas que se ven ahora (auditoría 6, A2): en una caja que SwiftUI no observa. Como
    /// `@State` de un conjunto, cada fila que entraba al desplazarte volvía a armar la vista entera.
    @State private var visible = VisibleRows()
    /// Las filas filtradas y ordenadas: se vuelven a calcular solo si cambia lo que las arma.
    @State private var cache = RowCache()

    var body: some View {
        let parsed = LibraryQuery(query)
        let rows = currentRows()
        table(rows)
            .overlay {
                if rows.isEmpty {
                    if query.isEmpty {
                        if library.books.isEmpty {
                            MacEmptyState(library: LibraryEmptyKind(waitingForCloud: library.waitingForCloud, cloudGaveUp: library.cloudGaveUp),
                                          add: { model.addBooks() }, welcome: { model.welcomeRequested = true })
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
            // Si el orden es de una columna que no se ve (la tabla con la ficha no la tiene, o la
            // escondiste), se dice en la barra: si no, el orden no tenía encabezado (auditoría 4).
            // Mientras bajo tu biblioteca de iCloud no digo «0 libros» (auditoría 5).
            .navigationSubtitle([library.books.isEmpty && (library.waitingForCloud || library.cloudGaveUp) ? nil : rows.count.counted("libro", "libros"), hiddenSortLine]
                .compactMap { $0 }.joined(separator: " · "))
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
                    .macToolbarInk(active: !parsed.filters.isEmpty)
                    .help("Buscar solo en un dato: autor, serie, etiqueta, idioma, editorial, estado, ISBN o título")
                    Button { model.addBooks() } label: { Label(LibraryAction.addBooks.title, systemImage: LibraryAction.addBooks.symbol) }
                        // Mientras bajo tu biblioteca de iCloud, no: añadirlos los duplicaría (auditoría 5).
                        .disabled(library.waitingForCloud)
                        .help(model.addBooksBlocked ?? "\(LibraryAction.addBooks.title) (⌘O)")
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
                // Mientras bajo tu biblioteca no los añado, pero te digo por qué (auditoría 6).
                if let reason = model.addBooksBlocked {
                    library.explain(EmptyCopy.addWhileDownloadingTitle, reason)
                    return false
                }
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
    /// Las filas de la sección, filtradas y ordenadas; de la caché si nada cambió.
    private func currentRows() -> [MacBookRow] {
        let key = RowCache.Key(books: library.books, shelf: model.shelf, reviews: library.reviews,
                               section: section, query: query, sortOrder: sortOrder)
        return cache.rows(for: key) {
            let parsed = LibraryQuery(query)
            return Self.rows(library: library, shelf: model.shelf)
                .filter { section.contains($0) && parsed.matches($0.book) }
                .sorted(using: sortOrder)
        }
    }

    /// Como está armada ahora; hasta que el ancho se quede quieto la primera vez, la de ahora.
    private var tableLayout: TableLayoutKey {
        layout ?? TableLayoutKey(inspector: showsInspector, widthStep: widthStep)
    }

    @ViewBuilder
    private func table(_ rows: [MacBookRow]) -> some View {
        ScrollViewReader { scroller in
            Group {
                if tableLayout.inspector {
                    Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $narrowColumns) {
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
            .id(tableLayout)
            // Al volver a armarse (abrir o cerrar la ficha, cambiar el ancho), vuelve a donde ibas:
            // la primera fila que veías, o lo elegido (auditorías 4 y 5: antes regresaba arriba).
            // La primera visible se anota antes de rearmar: al rearmarse, las celdas se van y vacían
            // la lista antes de llegar aquí (auditoría 6).
            .onChange(of: tableLayout) {
                let firstVisible = visible.anchor
                let chosen = rows.first { selection.contains($0.id) }?.id
                guard let id = firstVisible ?? chosen else { return }
                // Solo de arriba abajo (auditoría 6): `.top` y `.center` tienen x = 0.5 y, con la tabla
                // más ancha que la vista, la corrían de lado y no se veía el título.
                Task { @MainActor in scroller.scrollTo(id, anchor: firstVisible == nil ? Self.middleLeading : .topLeading) }
            }
        }
        .onGeometryChange(for: Int.self) { Int($0.size.width / Theme.Mac.column) } action: { widthStep = $0 }
        // Se rearma cuando el ancho (y la ficha) se quedan quietos, una sola vez, no a cada paso.
        .task(id: TableLayoutKey(inspector: showsInspector, widthStep: widthStep)) {
            try? await Task.sleep(for: Theme.Mac.relayoutPause)
            guard !Task.isCancelled else { return }
            let next = TableLayoutKey(inspector: showsInspector, widthStep: widthStep)
            guard next != layout else { return }
            visible.anchor = currentRows().first { visible.ids.contains($0.id) }?.id
            // Más angosta que la última vez: los anchos guardados dejaban la tabla más ancha que la
            // vista, corrida de lado y sin título. Se vuelven a repartir; lo que escondiste se queda.
            if next.widthStep < savedStep {
                columns = Self.keepingVisibility(of: columns)
                narrowColumns = Self.keepingVisibility(of: narrowColumns)
            }
            savedStep = next.widthStep
            layout = next
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
        TableColumn("Título", value: \MacBookRow.titleKey) { (row: MacBookRow) in
            MacCell(text: row.title, role: .title)
                .onAppear { visible.ids.insert(row.id) }
                .onDisappear { visible.ids.remove(row.id) }
        }
            .width(min: Theme.Mac.column, ideal: Theme.Mac.titleColumn)
            .customizationID("titulo")
        TableColumn("Autor", value: \MacBookRow.authorKey) { (row: MacBookRow) in MacCell(text: row.author) }
            .width(min: Theme.Mac.nameColumn, ideal: Theme.Mac.column, max: Theme.Mac.nameColumnMax)
            .customizationID("autor")
        TableColumn("Serie", value: \MacBookRow.seriesKey) { (row: MacBookRow) in MacCell(text: row.seriesLabel, role: .secondary) }
            .width(min: Theme.Mac.nameColumn, ideal: Theme.Mac.column, max: Theme.Mac.nameColumnMax)
            .customizationID("serie")
    }

    @TableColumnBuilder<MacBookRow, KeyPathComparator<MacBookRow>>
    private var lowColumns: some TableColumnContent<MacBookRow, KeyPathComparator<MacBookRow>> {
        TableColumn("Etiquetas", value: \MacBookRow.tagsKey) { (row: MacBookRow) in MacCell(text: row.tagsLabel, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: roomy ? Theme.Mac.column : Theme.Mac.shortColumn)
            .customizationID("etiquetas")
        TableColumn("Avance", value: \MacBookRow.progress) { (row: MacBookRow) in MacCell(text: row.progressLabel, role: .secondary) }
            .width(min: Theme.Mac.narrowColumn, ideal: roomy ? Theme.Mac.shortColumn : Theme.Mac.narrowColumn)
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
            .width(min: Theme.Mac.narrowColumn, ideal: roomy ? Theme.Mac.column : Theme.Mac.shortColumn)
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

    /// Las mismas columnas a la vista, sin los anchos guardados.
    static func keepingVisibility(of old: TableColumnCustomization<MacBookRow>) -> TableColumnCustomization<MacBookRow> {
        var fresh = TableColumnCustomization<MacBookRow>()
        for column in sortColumns { fresh[visibility: column.id] = old[visibility: column.id] }
        return fresh
    }

    /// Una tabla angosta: las columnas de a lado piden poco y el título se queda con el espacio.
    private var roomy: Bool { CGFloat(tableLayout.widthStep) * Theme.Mac.column >= Theme.Mac.roomyTable }

    /// El renglón a media altura, pegado a la orilla de inicio (sin correr de lado).
    static let middleLeading = UnitPoint(x: 0, y: 0.5)

    /// La clave con que se vuelve a armar la tabla.
    private struct TableLayoutKey: Hashable {
        let inspector: Bool
        let widthStep: Int
    }

    /// Las filas a la vista y la primera de ellas al rearmar. Una clase: cambiarla no vuelve a
    /// armar la vista.
    final class VisibleRows {
        var ids = Set<UUID>()
        var anchor: UUID?
    }

    /// Las filas ya filtradas y ordenadas, con lo que las armó. Comparar los arreglos de libros es
    /// casi gratis si no cambiaron (comparten memoria); filtrar y ordenar miles de filas, no.
    final class RowCache {
        struct Key: Equatable {
            let books: [Book]
            let shelf: [ShelfBook]
            let reviews: [UUID: [MetadataCandidate]]
            let section: MacSection
            let query: String
            let sortOrder: [KeyPathComparator<MacBookRow>]
        }

        private var key: Key?
        private var rows: [MacBookRow] = []

        func rows(for key: Key, make: () -> [MacBookRow]) -> [MacBookRow] {
            if key != self.key {
                rows = make()
                self.key = key
            }
            return rows
        }
    }

    /// Las columnas por las que se puede ordenar, con su nombre y su id de la tabla.
    private static let sortColumns: [(key: PartialKeyPath<MacBookRow>, id: String, name: String)] = [
        (\MacBookRow.coverKey, "portada", "Portada"), (\MacBookRow.titleKey, "titulo", "Título"),
        (\MacBookRow.authorKey, "autor", "Autor"), (\MacBookRow.seriesKey, "serie", "Serie"),
        (\MacBookRow.tagsKey, "etiquetas", "Etiquetas"), (\MacBookRow.progress, "avance", "Avance"),
        (\MacBookRow.stateLabel, "estado", "Estado"), (\MacBookRow.format, "formato", "Formato"),
        (\MacBookRow.added, "agregado", "Agregado"), (\MacBookRow.language, "idioma", "Idioma"),
        (\MacBookRow.rating, "valoracion", "Valoración"), (\MacBookRow.publisherKey, "editorial", "Editorial"),
        (\MacBookRow.published, "publicado", "Publicado"), (\MacBookRow.isbn, "isbn", "ISBN"),
    ]
    /// Las que no tiene la tabla con la ficha abierta.
    private static let wideOnly: Set<String> = ["etiquetas", "avance", "agregado"]
    /// Las que empiezan escondidas (`defaultVisibility(.hidden)`).
    private static let startHidden: Set<String> = ["idioma", "valoracion", "editorial", "publicado", "isbn"]

    /// «por Agregado» si la tabla está ordenada por una columna que no se ve.
    private var hiddenSortLine: String? {
        guard let order = sortOrder.first,
              let column = Self.sortColumns.first(where: { $0.key == order.keyPath as PartialKeyPath<MacBookRow> }) else { return nil }
        let customization = tableLayout.inspector ? narrowColumns : columns
        let visibility = customization[visibility: column.id]
        let hidden = (tableLayout.inspector && Self.wideOnly.contains(column.id)) || visibility == .hidden
            || (Self.startHidden.contains(column.id) && visibility != .visible)
        guard hidden else { return nil }
        return "por \(column.name)" + (order.order == .reverse ? " (al revés)" : "")
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
