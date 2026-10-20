import SwiftUI

/// Biblioteca: título con dos acciones, filtros en texto, conteo con el orden,
/// y portadas (con series en pila) o lista con índice A–Z.
struct LibraryScreen: View {
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
                            Button { model.importing = true } label: { Image(systemName: "plus") }
                                .accessibilityLabel("Añadir libro")
                        }

                        FilterBar(items: LibraryFilter.allCases, selection: $filter) { $0.rawValue }
                            .padding(.top, Theme.Space.m)

                        HStack {
                            Text(summary)
                            Spacer()
                            Menu {
                                Picker("Ordenar por", selection: $sort) {
                                    ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                                }
                            } label: {
                                Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                                    .labelStyle(TrailingIconLabelStyle())
                                    .foregroundStyle(Theme.ink)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ordenar: \(sort.rawValue)")
                        }
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.m)

                        if !model.library.reviews.isEmpty {
                            NavigationLink(value: ReviewInboxRef()) {
                                LinkRow(title: "Por revisar", value: "\(model.library.reviews.count)", marked: true)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, Theme.Space.m)
                        }

                        if model.shelf.isEmpty {
                            EmptyState(title: "Todavía no hay libros",
                                       message: "Toca + para añadir los primeros. También puedes migrar tu biblioteca de Calibre.")
                        } else if books.isEmpty {
                            EmptyState(title: "Nada por aquí", message: "Ningún libro coincide con «\(filter.rawValue)».")
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
                    // El índice solo tiene sentido con la lista ordenada por título.
                    if layout == .list && sort == .title && !books.isEmpty {
                        LetterIndex { letter in
                            if let target = books.first(where: { $0.sortTitle.firstLetter == letter }) {
                                withAnimation { scroller.scrollTo(target.id, anchor: .top) }
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
        default: break
        }
    }

    private var summary: String {
        if let progress = model.library.progress {
            return "Añadiendo \(min(progress.done + 1, progress.total)) de \(progress.total)…"
        }
        if !model.library.identifying.isEmpty {
            return "Buscando datos en internet…"
        }
        let all = model.shelf
        return "\(all.count) libros · \(all.filter { !$0.inCloudOnly }.count) en este iPhone"
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

/// «Recientes ⇅»: texto primero, icono después.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.xs) {
            configuration.title
            configuration.icon.font(.caption2.weight(.semibold))
        }
    }
}
