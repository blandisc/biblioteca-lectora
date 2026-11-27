#if os(macOS)
import AppKit
import LectoraCore
import SwiftUI

/// Lo que se ve a la derecha de la barra lateral.
enum MacSection: Hashable {
    case desk, notebook, search
    case all, reading, toRead, finished, review, noCover
    case author(String), series(String), tag(String), language(String)

    var title: String {
        switch self {
        case .desk: "Mesa"
        case .notebook: "Cuaderno"
        case .search: "Buscar"
        case .all: "Biblioteca"
        case .reading: "Leyendo"
        case .toRead: "Por leer"
        case .finished: "Leídos"
        case .review: "Por revisar"
        case .noCover: "Sin portada"
        case .author(let name), .series(let name), .tag(let name), .language(let name): name
        }
    }

    func contains(_ row: MacBookRow) -> Bool {
        switch self {
        case .desk, .notebook, .search, .all: true
        case .reading: row.state == .reading
        case .toRead: row.state == .toRead
        case .finished: row.state == .finished
        case .review: row.inReview
        case .noCover: !row.hasCover
        case .author(let name): row.book.authors.contains(name)
        case .series(let name): row.book.series == name
        case .tag(let name): row.book.tags.contains(name)
        case .language(let code): row.book.language == code
        }
    }
}

/// La Mac como mesa de trabajo de tu biblioteca (MG-1, 26 nov 2026): barra lateral, tabla
/// y ficha, como Música o Fotos. Leer (Mesa y Cuaderno) vive en la misma barra lateral.
struct MacLibraryWindow: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: MacSection? = {
        // Capturas: `-screenshot.tab desk|notebook` abre en la Mesa o el Cuaderno.
        switch LaunchOptions.tab {
        case "desk": .desk
        case "notebook": .notebook
        case "search": .search
        default: .all
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
            case .search: SearchScreen().navigationTitle("Buscar")
            default: MacBookTable(library: model.library, section: section ?? .all)
            }
        }
        // El tamaño ideal es con el que abre la primera vez (si no, abría en el mínimo).
        .frame(minWidth: Theme.Mac.window.width, idealWidth: Theme.Mac.defaultWindow.width,
               minHeight: Theme.Mac.window.height, idealHeight: Theme.Mac.defaultWindow.height)
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

    var body: some View {
        let rows = MacBookTable.rows(library: library, shelf: shelf)
        List(selection: $selection) {
            Section("Leer") {
                Label("Mesa", systemImage: "book").tag(MacSection.desk)
                Label("Cuaderno", systemImage: "note.text").tag(MacSection.notebook)
                Label("Buscar en todo", systemImage: "magnifyingglass").tag(MacSection.search)
            }
            Section("Biblioteca") {
                item(.all, "books.vertical", rows.count)
                item(.reading, "book", rows.filter { $0.state == .reading }.count)
                item(.toRead, "bookmark", rows.filter { $0.state == .toRead }.count)
                item(.finished, "checkmark.circle", rows.filter { $0.state == .finished }.count)
                item(.review, "questionmark.circle", rows.filter(\.inReview).count)
                item(.noCover, "photo", rows.filter { !$0.hasCover }.count)
            }
            Section("Explorar") {
                group("Autores", "person.2", values(rows.flatMap(\.book.authors)), MacSection.author, icon: "person", field: .author)
                group("Series", "square.stack", values(rows.compactMap(\.book.series)), MacSection.series, icon: "square.stack", field: .series)
                group("Etiquetas", "tag", values(rows.flatMap(\.book.tags)), MacSection.tag, icon: "tag", field: .tag)
                group("Idiomas", "globe", values(rows.compactMap(\.book.language)), MacSection.language, icon: "globe", field: nil)
            }
        }
        .listStyle(.sidebar)
        #if DEBUG
        // Capturas: `-screenshot.demo macRename` abre «Renombrar o juntar» con el primer autor;
        // `-screenshot.query Nombre` además lo renombra así (prueba de punta a punta).
        .task {
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
    }

    private func group(_ title: String, _ symbol: String, _ values: [(String, Int)],
                       _ make: @escaping (String) -> MacSection, icon: String,
                       field: CatalogRename.Field?) -> some View {
        DisclosureGroup {
            ForEach(values, id: \.0) { value, count in
                Label(value, systemImage: icon).badge(count).tag(make(value))
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
