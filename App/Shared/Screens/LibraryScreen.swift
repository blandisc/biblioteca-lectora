import LectoraCore
import SwiftUI

/// Biblioteca: título con dos acciones, filtros en texto, conteo con el orden,
/// y portadas (con series en pila) o lista con índice A–Z.
struct LibraryScreen: View {
    /// Desde cuántos libros aparece el índice A–Z.
    static let letterIndexMinimum = 15
    @EnvironmentObject private var model: AppModel
    @AppStorage(LibraryKeys.sort) private var sort: LibrarySort = .recent
    @AppStorage(LibraryKeys.layout) private var layout: LibraryLayout = .covers
    @State private var filter: LibraryFilter = .all
    @State private var path = NavigationPath()

    private var books: [ShelfBook] {
        sort.sorted(model.shelf.filter(filter.includes))
    }

    /// En portadas, cada serie se ve como una sola pila con su número de libros,
    /// en el lugar de su libro más reciente según el orden elegido.
    private func coverItems(_ books: [ShelfBook]) -> [ShelfBook] {
        let groups = Dictionary(grouping: books.filter { $0.series != nil }) { SeriesRef($0)! }
        var seen = Set<SeriesRef>()
        return books.compactMap { book in
            guard let ref = SeriesRef(book), let members = groups[ref], members.count > 1 else { return book }
            guard seen.insert(ref).inserted else { return nil }
            var stack = members.min { ($0.seriesIndex ?? 0) < ($1.seriesIndex ?? 0) } ?? book
            stack.seriesCount = members.count
            return stack
        }
    }

    var body: some View {
        let books = self.books
        return NavigationStack(path: $path) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenHeading(title: "Biblioteca") {
                            Button {
                                withAnimation(Theme.Motion.standard) { layout = layout == .covers ? .list : .covers }
                            } label: {
                                Image(systemName: layout == .covers ? "list.bullet" : "square.grid.2x2")
                            }
                            .accessibilityLabel(layout == .covers ? "Ver como lista" : "Ver portadas")
                            // El único acento verde de la pantalla.
                            AccentIconButton(systemImage: LibraryAction.addBooks.symbol, label: LibraryAction.addBooks.title) { model.importing = true }
                        }

                        FilterBar(items: LibraryFilter.options(for: model.shelf), selection: $filter) { $0.title }
                            .padding(.top, Theme.Space.s)

                        CountLine(text: summary) {
                            SortMenu(options: LibrarySort.allCases, selection: $sort) { $0.rawValue }
                        }

                        if !model.library.reviews.isEmpty || !model.library.filled.isEmpty {
                            NavigationLink(value: ReviewInboxRef()) {
                                // El número es lo que espera una decisión tuya; lo que se completó solo se
                                // cuenta solo cuando no queda nada dudoso.
                                LinkRow(title: "Por revisar", value: "\(model.library.reviews.isEmpty ? model.library.filled.count : model.library.reviews.count)",
                                        marked: !model.library.reviews.isEmpty)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, Theme.Space.l)
                        }

                        // Estantes (CB-1): búsquedas guardadas que se llenan solas.
                        ForEach(model.library.shelves) { shelf in
                            NavigationLink(value: ShelfRef(id: shelf.id)) {
                                LinkRow(title: shelf.name, value: "\(model.library.books.filter(shelf.contains).count)")
                            }
                            .buttonStyle(.plain)
                        }

                        if model.shelf.isEmpty {
                            EmptyState(title: EmptyCopy.noBooks.title, message: EmptyCopy.noBooks.message,
                                       actionTitle: LibraryAction.addBooks.title, systemImage: LibraryAction.addBooks.symbol) { model.importing = true }
                        } else if books.isEmpty {
                            EmptyState(title: EmptyCopy.noMatch(filter.title).title, message: EmptyCopy.noMatch(filter.title).message)
                        } else {
                            switch layout {
                            case .covers: grid(coverItems(books)).padding(.top, Theme.Space.l)
                            case .list: list(books).padding(.top, Theme.Space.s)
                            }
                        }
                    }
                    .screenContent()
                }
                .overlay(alignment: .trailing) {
                    // El índice solo tiene sentido con la lista ordenada por título y más
                    // libros de los que caben en una pantalla (con dos, eran 27 letras de adorno).
                    if layout == .list && sort == .title && books.count >= Self.letterIndexMinimum {
                        LetterIndex { letter in
                            if let target = books.first(where: { $0.sortTitle.firstLetter == letter }) {
                                withAnimation(Theme.Motion.standard) { scroller.scrollTo(target.id, anchor: .top) }
                            }
                        }
                    }
                }
            }
            .screen()
            .onAppear(perform: openScreenForScreenshots)
        }
    }

    /// Capturas automáticas: abre la pantalla pedida al arrancar.
    private func openScreenForScreenshots() {
        guard path.isEmpty else { return }
        switch LaunchOptions.screen {
        case "review": path.append(ReviewInboxRef())
        case "detail": if let first = model.shelf.first { path.append(first) }
        case "shelf": if let first = model.library.shelves.first { path.append(ShelfRef(id: first.id)) }
        default: break
        }
    }

    private var summary: String {
        if let line = model.library.progressLine { return line }
        if !model.library.identifying.isEmpty {
            return "Buscando datos en internet…"
        }
        let all = model.shelf
        let inCloud = all.filter(\.inCloudOnly).count
        let books = all.count.counted("libro", "libros")
        return inCloud == 0 ? books : "\(books) · \(inCloud) en la nube"
    }

    private func grid(_ items: [ShelfBook]) -> some View {
        CoverGrid {
            ForEach(items) { book in
                Group {
                    if book.seriesCount != nil, let ref = SeriesRef(book) {
                        NavigationLink(value: ref) { CoverCell(book: book) }
                    } else {
                        NavigationLink(value: book) { CoverCell(book: book) }
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func list(_ books: [ShelfBook]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    BookRow(book: book) {
                        if book.inCloudOnly {
                            Image(systemName: "icloud").accessibilityLabel("En iCloud")
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(book.id)
            }
        }
        // Deja libre la columna del índice A–Z.
        .padding(.trailing, sort == .title ? Theme.Space.s : 0)
    }
}
