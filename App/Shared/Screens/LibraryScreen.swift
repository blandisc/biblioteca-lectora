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
    /// Capturas: `-screenshot.filter Leyendo` abre con ese filtro elegido (UX-2a).
    @State private var filter: LibraryFilter = .all
    @State private var path = NavigationPath()
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Dónde termina el renglón del conteo y el orden: el índice A–Z empieza debajo.
    @State private var letterIndexTop: CGFloat = 0
    private static let contentSpace = "biblioteca"

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

    /// El índice solo tiene sentido con la lista ordenada por título y más libros de los que
    /// caben en una pantalla (con dos, eran 27 letras de adorno), y no con la letra más grande.
    private func showsLetterIndex(_ books: [ShelfBook]) -> Bool {
        layout == .list && sort == .title && books.count >= Self.letterIndexMinimum && LetterIndex.shows(at: typeSize)
    }

    /// Donde iría el índice A–Z pero la letra es tan grande que no cabe.
    private func jumpsByLetter(_ books: [ShelfBook]) -> Bool {
        layout == .list && sort == .title && books.count >= Self.letterIndexMinimum && !LetterIndex.shows(at: typeSize)
    }

    private func jump(to letter: String, in books: [ShelfBook], _ scroller: ScrollViewProxy) {
        if let target = books.first(where: { $0.sortTitle.firstLetter == letter }) {
            withAnimation(Theme.Motion.standard) { scroller.scrollTo(target.id, anchor: .top) }
        }
    }

    /// Sin libros porque tu biblioteca no ha bajado de iCloud (bajando o ya dejé de esperar).
    private var cloudEmpty: Bool {
        model.shelf.isEmpty && (model.library.waitingForCloud || model.library.cloudGaveUp)
    }

    var body: some View {
        let books = self.books
        let indexed = showsLetterIndex(books)
        return NavigationStack(path: $path) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenHeading(title: "Biblioteca") {
                            // Sin libros que ver mientras bajo (o dejé de esperar) no hay nada que acomodar.
                            if !cloudEmpty {
                                IconButton(systemImage: layout == .covers ? "list.bullet" : "square.grid.2x2",
                                           label: layout == .covers ? "Ver como lista" : "Ver portadas") {
                                    withAnimation(Theme.Motion.standard) { layout = layout == .covers ? .list : .covers }
                                }
                            }
                            // El único acento verde de la pantalla. Mientras bajo tu biblioteca de iCloud se
                            // ve apagado y abajo digo por qué (auditoría 6: escondido, no sabías por qué).
                            AccentIconButton(systemImage: LibraryAction.addBooks.symbol, label: LibraryAction.addBooks.title) { model.addBooks() }.disabled(model.addBooksBlocked != nil)
                        }

                        if !cloudEmpty {
                            FilterBar(items: LibraryFilter.options(for: model.shelf), selection: $filter) { $0.title }
                                .padding(.top, Theme.Space.s)
                        }
                        // Con libros a la vista, el porqué del «+» apagado (sin libros lo dice el vacío).
                        if let blocked = model.addBooksBlocked, !model.shelf.isEmpty {
                            Text(blocked)
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryInk)
                                .padding(.top, Theme.Space.s)
                        }

                        // Del conteo para abajo, todo deja libre la columna del índice A–Z.
                        VStack(alignment: .leading, spacing: 0) {
                            // Mientras bajo tu biblioteca de iCloud no digo «0 libros» (auditoría 5): el vacío dice qué pasa.
                            // Ni «0 libros» si dejé de esperar: el vacío dice que no ha bajado (auditoría 6).
                            if !cloudEmpty {
                                CountLine(text: summary(books)) {
                                    // Sin libros a la vista no hay nada que ordenar (auditoría 4).
                                    if !books.isEmpty {
                                        SortMenu(options: LibrarySort.allCases, selection: $sort) { $0.rawValue }
                                    }
                                    // Con la letra más grande no hay índice A–Z: un menú salta a la letra.
                                    if jumpsByLetter(books) {
                                        LetterJumpMenu(letters: LetterIndex.letters.filter { letter in books.contains { $0.sortTitle.firstLetter == letter } }) { letter in
                                            jump(to: letter, in: books, scroller)
                                        }
                                    }
                                }
                                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.contentSpace)).maxY } action: { letterIndexTop = $0 }
                            }

                            // Solo en «Todos»: con un filtro, sus libros no son los que se ven (auditoría 3).
                            if filter == .all, !model.library.reviews.isEmpty || !model.library.filled.isEmpty {
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
                                LibraryEmptyState(kind: LibraryEmptyKind(waitingForCloud: model.library.waitingForCloud,
                                                                         cloudGaveUp: model.library.cloudGaveUp),
                                                  add: { model.addBooks() }, welcome: { model.welcomeRequested = true })
                            } else if books.isEmpty {
                                EmptyState(title: EmptyCopy.noMatch(filter.title).title, message: EmptyCopy.noMatch(filter.title).message,
                                           actionTitle: EmptyCopy.showAll) { filter = .all }
                            } else {
                                switch layout {
                                case .covers: grid(coverItems(books)).padding(.top, Theme.Space.l)
                                case .list: list(books).padding(.top, Theme.Space.s)
                                }
                            }
                        }
                        .padding(.trailing, indexed ? Theme.Space.letterIndex : 0)
                    }
                    .screenContent(wide: true)
                    .coordinateSpace(.named(Self.contentSpace))
                }
                .overlay(alignment: .trailing) {
                    if indexed {
                        LetterIndex { letter in jump(to: letter, in: books, scroller) }
                        .frame(maxHeight: .infinity)
                        .padding(.top, letterIndexTop)
                    }
                }
            }
            .screen()
            .onAppear(perform: openScreenForScreenshots)
            // Si el filtro elegido se queda sin libros y desaparece, vuelve a «Todos».
            .onChange(of: LibraryFilter.options(for: model.shelf)) { _, options in
                if !options.contains(filter) { filter = .all }
            }
        }
    }

    /// Capturas automáticas: abre la pantalla pedida al arrancar.
    private func openScreenForScreenshots() {
        if let wanted = LaunchOptions.filter,
           let chosen = LibraryFilter.options(for: model.shelf).first(where: { $0.title == wanted }) {
            filter = chosen
        }
        guard path.isEmpty else { return }
        switch LaunchOptions.screen {
        case "review": path.append(ReviewInboxRef())
        case "detail", "edit", "candidates", "cover":
            let wanted = LaunchOptions.book.flatMap { title in model.shelf.first { $0.title.contains(title) } }
            if let first = wanted ?? model.shelf.first { path.append(first) }
        case "shelf": if let first = model.library.shelves.first { path.append(ShelfRef(id: first.id)) }
        case "series": if let ref = model.shelf.lazy.compactMap(SeriesRef.init).first { path.append(ref) }
        default: break
        }
    }

    /// Cuenta lo que ves: con un filtro, los libros de ese filtro (antes decía «9 libros»
    /// con «Leyendo» elegido y uno solo a la vista, UX-2a).
    private func summary(_ shown: [ShelfBook]) -> String {
        if let line = model.library.progressLine { return line }
        if !model.library.identifying.isEmpty {
            return "Buscando datos en internet…"
        }
        let inCloud = shown.filter(\.inCloudOnly).count
        var books = shown.count.counted("libro", "libros")
        // En «Series» se ven pilas, no libros: «1 serie · 3 libros» (decía «3 libros» bajo una pila).
        if filter == .series {
            books = "\(Set(shown.compactMap(SeriesRef.init)).count.counted("serie", "series")) · \(books)"
        }
        return inCloud == 0 || filter == .cloud ? books : "\(books) · \(inCloud) en la nube"
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
    }
}
