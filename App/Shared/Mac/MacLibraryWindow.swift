#if os(macOS)
import AppKit
import LectoraCore
import SwiftUI

/// Lo que se ve a la derecha de la barra lateral.
enum MacSection: Hashable {
    case desk, notebook, search
    /// Posibles duplicados (CB-3).
    case duplicates
    case all, review, noCover
    /// Por estado: los mismos nombres y la misma regla que los filtros del iPhone (C1).
    case state(ReadingState)
    case author(String), series(String), tag(String), language(String)
    /// Un estante: búsqueda guardada (CB-1).
    case shelf(SavedShelf)

    var title: String {
        switch self {
        case .desk: "Mesa"
        case .notebook: "Cuaderno"
        case .search: SearchWording.title
        case .duplicates: Duplicates.title
        case .all: "Biblioteca"
        case .state(let state): state.group
        case .review: "Por revisar"
        case .noCover: "Sin portada"
        case .author(let name), .series(let name), .tag(let name): name
        case .language(let code): BookFields.languageName(code)
        case .shelf(let shelf): shelf.name
        }
    }

    func contains(_ row: MacBookRow) -> Bool {
        switch self {
        case .desk, .notebook, .search, .duplicates, .all: true
        case .state(let state): row.state == state
        case .review: row.inReview
        case .noCover: !row.hasCover
        case .author(let name): row.book.authors.contains(name)
        case .series(let name): row.book.series == name
        case .tag(let name): row.book.tags.contains(name)
        case .language(let code): row.book.language == code
        case .shelf(let shelf): shelf.contains(row.book)
        }
    }
}

/// La Mac como mesa de trabajo de tu biblioteca (MG-1, 26 nov 2026): barra lateral, tabla
/// y ficha, como Música o Fotos. Leer (Mesa y Cuaderno) vive en la misma barra lateral.
struct MacLibraryWindow: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: MacSection? = { () -> MacSection? in
        // Capturas: `-screenshot.tab desk|notebook` abre en la Mesa o el Cuaderno.
        switch LaunchOptions.tab {
        case "desk": return .desk
        case "notebook": return .notebook
        case "search": return .search
        default:
            #if DEBUG
            // `-screenshot.section review|noCover|duplicates|finished|author:Nombre|series:Nombre|tag:Nombre`.
            if let raw = UserDefaults.standard.string(forKey: "screenshot.section") {
                let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
                switch (parts[0], parts.count > 1 ? parts[1] : "") {
                case ("review", _): return .review
                case ("noCover", _): return .noCover
                case ("duplicates", _): return .duplicates
                case ("finished", _): return .state(.finished)
                case ("reading", _): return .state(.reading)
                case ("author", let name): return .author(name)
                case ("series", let name): return .series(name)
                case ("tag", let name): return .tag(name)
                default: break
                }
            }
            #endif
            return .all
        }
    }()

    var body: some View {
        NavigationSplitView {
            MacSidebar(library: model.library, shelf: model.shelf, selection: $section)
                .navigationSplitViewColumnWidth(min: Theme.Mac.sidebarMin, ideal: Theme.Mac.sidebar)
        } detail: {
            switch section ?? .all {
            case .desk: MesaScreen().navigationTitle("Mesa")
            case .notebook: NotebookScreen().navigationTitle("Cuaderno")
            // Buscar en todo (SG-3): libros, subrayados y notas. La búsqueda de la tabla es solo de libros.
            case .search: SearchScreen().navigationTitle(SearchWording.title)
            case .duplicates: MacDuplicatesView(library: model.library)
            default: MacBookTable(library: model.library, section: section ?? .all)
            }
        }
        // Buscar datos en lote (CB-4): cómo va, en cualquier sección.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let batch = model.library.batch {
                MacBatchBar(progress: batch, stop: model.library.stopBatch, close: model.library.clearBatch)
            }
        }
        // De papel (MX-B): la barra de la ventana sobre el mismo papel que el contenido.
        .macWindowPaper()
        // El tamaño ideal es con el que abre la primera vez (si no, abría en el mínimo).
        .frame(minWidth: Theme.Mac.window.width, idealWidth: Theme.Mac.defaultWindow.width,
               minHeight: Theme.Mac.window.height, idealHeight: Theme.Mac.defaultWindow.height)
    }
}

/// Abajo de la ventana mientras se buscan datos de muchos libros (CB-4): cuántos van, con
/// «Detener»; al terminar, el resumen («22 completados · 6 a Por revisar»).
private struct MacBatchBar: View {
    let progress: BatchLookup.Progress
    let stop: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            if progress.finished {
                Image(systemName: progress.stopped ? "stop.circle" : "checkmark.circle")
                    .foregroundStyle(Theme.secondaryInk)
                Text(progress.stopped ? "Detenido · \(progress.summary)" : progress.summary)
                Spacer()
                Button("Cerrar aviso", action: close)
            } else {
                Text("Buscando datos · \(progress.done.counted("libro", "libros")) de \(progress.total)")
                    .monospacedDigit()
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                    .frame(maxWidth: Theme.Mac.batchProgress)
                Spacer()
                Text("Sigue aunque cierres la ventana")
                    .foregroundStyle(Theme.secondaryInk)
                Button("Detener búsqueda", action: stop)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.paper)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// La barra lateral: leer, la biblioteca por estado y explorar por autor, serie, etiqueta o idioma.
private struct MacSidebar: View {
    @ObservedObject var library: LibraryStore
    let shelf: [ShelfBook]
    @Binding var selection: MacSection?
    @Environment(\.undoManager) private var undoManager
    /// Renombrar o fusionar (CB-2), desde el clic derecho en un autor, serie o etiqueta.
    @State private var renaming: MacCatalogSheet.Target?
    @State private var renamingShelf: SavedShelf?
    /// Borrar un estante se confirma, como en el iPhone.
    @State private var deletingShelf: SavedShelf?

    var body: some View {
        let rows = MacBookTable.rows(library: library, shelf: shelf)
        List(selection: $selection) {
            Section("Leer") {
                Label("Mesa", systemImage: "book").tag(MacSection.desk)
                Label("Cuaderno", systemImage: "note.text").tag(MacSection.notebook)
                Label(SearchWording.title, systemImage: "magnifyingglass").tag(MacSection.search)
            }
            Section("Biblioteca") {
                item(.all, "books.vertical", rows.count)
                ForEach(ReadingState.allCases, id: \.self) { state in
                    let count = rows.filter { $0.state == state }.count
                    // «Abandonados» sale solo si hay alguno, igual que en el iPhone.
                    if state != .abandoned || count > 0 || selection == .state(state) {
                        item(.state(state), state.symbol, count)
                    }
                }
                item(.review, "questionmark.circle", rows.filter(\.inReview).count)
                item(.noCover, "photo", rows.filter { !$0.hasCover }.count)
                let duplicates = library.duplicateGroups().count
                if duplicates > 0 || selection == .duplicates {
                    item(.duplicates, Duplicates.symbol, duplicates)
                }
            }
            if !library.shelves.isEmpty {
                Section("Estantes") {
                    ForEach(library.shelves) { shelf in
                        Label(shelf.name, systemImage: "books.vertical")
                            .badge(rows.filter { shelf.contains($0.book) }.count)
                            .tag(MacSection.shelf(shelf))
                            .contextMenu {
                                Button("Renombrar estante…") { renamingShelf = shelf }
                                Button("Borrar estante…", role: .destructive) { deletingShelf = shelf }
                            }
                    }
                }
            }
            Section("Explorar") {
                group("Autores", "person.2", values(rows.flatMap(\.book.authors)), MacSection.author, icon: "person", field: .author)
                group("Series", "square.stack", values(rows.compactMap(\.book.series)), MacSection.series, icon: "square.stack", field: .series)
                group("Etiquetas", "tag", values(rows.flatMap(\.book.tags)), MacSection.tag, icon: "tag", field: .tag)
                group("Idiomas", "globe", values(rows.compactMap(\.book.language)), MacSection.language, icon: "globe", field: nil,
                      display: BookFields.languageName)
            }
        }
        .listStyle(.sidebar)
        .macSidebarPaper()
        #if DEBUG
        // Capturas: `-screenshot.demo macDuplicates` importa copias y abre los duplicados; `macBatch` busca datos de los incompletos; `macRename` abre «Renombrar o juntar» con el primer autor;
        // `-screenshot.query Nombre` además lo renombra así (prueba de punta a punta).
        .task {
            if LaunchOptions.demo == "macDuplicates" {
                // Importa `Documents/Duplicados` (copias de libros que ya están) y abre «Posibles duplicados».
                let folder = URL.documentsDirectory.appendingPathComponent("Duplicados", isDirectory: true)
                let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
                _ = await library.importFiles(files)
                // `-screenshot.query juntar` además junta el primer grupo en el que se queda (prueba de punta a punta).
                if UserDefaults.standard.string(forKey: "screenshot.query") == "juntar", let group = library.duplicateGroups().first,
                   let keep = DuplicateFinder.preferred(group, highlights: Dictionary(uniqueKeysWithValues: group.map {
                       ($0.id, AnnotationStore.shared.annotations(forBook: $0.id).count)
                   })) {
                    let report = try? library.merge(keep: keep, others: group.map(\.id).filter { $0 != keep })
                    print("juntar:", report.map { "\($0)" } ?? "falló")
                }
                selection = .duplicates
                return
            }
            if LaunchOptions.demo == "macBatch" {
                // Buscar datos de los incompletos, como el clic derecho en «Todos los libros».
                library.lookUpMany(library.incompleteBooks())
                return
            }
            guard LaunchOptions.demo == "macRename" else { return }
            try? await Task.sleep(for: .seconds(3))
            guard let first = values(for: .author, rows).first?.0 else { return }
            if let name = UserDefaults.standard.string(forKey: "screenshot.query") {
                library.rename(CatalogRename(field: .author, from: [first], to: name))
                selection = .author(name)
            } else {
                renaming = .init(field: .author, value: first)
            }
        }
        #endif
        .renameShelfAlert($renamingShelf) { shelf in
            let wasSelected = selection.map { if case .shelf(let old) = $0 { old.id == shelf.id } else { false } } ?? false
            library.saveShelf(shelf)
            if wasSelected { selection = .shelf(shelf) }
        }
        .deleteShelfConfirmation($deletingShelf) { shelf in
            if case .shelf(shelf) = selection { selection = .all }
            library.removeShelf(id: shelf.id)
        }
        .sheet(item: $renaming) { target in
            MacCatalogSheet(target: target, values: values(for: target.field, rows), library: library) { final in
                // Si estabas viendo lo que cambió de nombre, sigues viéndolo con el nombre nuevo.
                switch (selection, target.field) {
                case (.author(target.value), .author): selection = .author(final)
                case (.series(target.value), .series): selection = .series(final)
                case (.tag(target.value), .tag): selection = .tag(final)
                default: break
                }
            }
        }
    }

    private func values(for field: CatalogRename.Field, _ rows: [MacBookRow]) -> [(String, Int)] {
        values(rows.flatMap { CatalogRename.values(field, in: $0.book) })
    }

    /// Los tomos 1, 2, 3…, con ⌘Z para deshacer.
    private func renumber(_ series: String) {
        let change = library.renumber(series: series)
        guard !change.originals.isEmpty else { return }
        let library = library
        undoManager?.registerUndo(withTarget: library) { store in
            MainActor.assumeIsolated { store.restore(change) }
        }
        undoManager?.setActionName("Renumerar tomos")
    }

    private func item(_ section: MacSection, _ symbol: String, _ count: Int) -> some View {
        Label(section == .all ? "Todos los libros" : section.title, systemImage: symbol)
            .badge(count)
            .tag(section)
            .contextMenu {
                // CB-4: datos para muchos libros a la vez.
                let ids = lookupTargets(for: section)
                Button(section == .all ? "Buscar datos de \(ids.count.counted("libro incompleto", "libros incompletos"))" : LibraryAction.findData(count: ids.count)) {
                    library.lookUpMany(ids)
                }
                .disabled(ids.isEmpty || library.batch.map { !$0.finished } == true)
            }
    }

    /// En «Todos», solo los incompletos; en las demás vistas, todos los de la vista.
    private func lookupTargets(for section: MacSection) -> [UUID] {
        if section == .all { return library.incompleteBooks() }
        return MacBookTable.rows(library: library, shelf: shelf).filter(section.contains).map(\.id)
    }

    private func group(_ title: String, _ symbol: String, _ values: [(String, Int)],
                       _ make: @escaping (String) -> MacSection, icon: String,
                       field: CatalogRename.Field?, display: @escaping (String) -> String = { $0 }) -> some View {
        DisclosureGroup {
            ForEach(values, id: \.0) { value, count in
                Label(display(value), systemImage: icon).badge(count).tag(make(value))
                    .contextMenu {
                        if let field {
                            Button("Renombrar o juntar…") { renaming = .init(field: field, value: value) }
                            if field == .series {
                                Button("Renumerar tomos 1, 2, 3…") { renumber(value) }
                            }
                        }
                    }
            }
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    /// Cada valor con cuántos libros lo tienen, en orden alfabético sin acentos.
    private func values(_ all: [String]) -> [(String, Int)] {
        Dictionary(all.map { ($0, 1) }, uniquingKeysWith: +)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }
}
#endif
