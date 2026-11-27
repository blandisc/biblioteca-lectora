import LectoraCore
import SwiftUI

/// Buscar, en su propio espacio del dock (y en la barra lateral de la Mac). Mismo título y
/// margen que las demás pantallas. Busca en tus libros, tus subrayados y tus notas (SG-3):
/// cada palabra, en cualquier orden y sin acentos; «autor:» o «serie:» acotan los libros y
/// sus subrayados, como en la tabla de la Mac.
struct SearchScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var recents: [RecentSearches.Item] = []
    /// «Ver los 12 subrayados»: de inicio solo los primeros.
    @State private var showsAllHighlights = false
    /// «Guardar como estante» con esta búsqueda (CB-1).
    @State private var savingShelf: String?

    private var term: String { query.trimmingCharacters(in: .whitespaces) }
    private var parsed: LibraryQuery { LibraryQuery(term) }

    private var books: [ShelfBook] {
        let parsed = parsed
        guard !parsed.isEmpty else { return [] }
        let found = Set(model.library.books.filter(parsed.matches).map(\.id.uuidString))
        return model.shelf.filter { found.contains($0.id) }
    }

    private var highlights: [Annotation] {
        let parsed = parsed
        guard term.count >= 2, !parsed.isEmpty else { return [] }
        // Con filtros, primero los libros que los cumplen (una vez, no por cada subrayado).
        let allowed = parsed.filters.isEmpty ? nil : Set(model.library.books.filter(parsed.matchesFilters).map(\.id))
        return model.annotations.allAnnotations().filter { highlight in
            if let allowed, !allowed.contains(highlight.bookID) { return false }
            return parsed.words.isEmpty || parsed.matches(text: [highlight.quote, highlight.note])
        }
    }

    /// Las notas no son de un libro: con `autor:` y compañía no salen.
    private var notes: [Note] {
        let parsed = parsed
        guard term.count >= 2, parsed.filters.isEmpty else { return [] }
        return model.notes.notes.filter { parsed.matches(text: [$0.text, $0.fileName]) }
    }

    /// Los últimos libros que abriste, con su avance.
    private var recentlyOpened: [ShelfBook] {
        model.shelf.filter { $0.lastReadAt != nil }
            .sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }
            .prefix(Theme.Reader.recentBooks).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Buscar")
                    // Campo propio bajo el título: el del sistema (`.searchable`) quedaba
                    // escondido con la barra de navegación y no había dónde escribir.
                    SearchField(prompt: "Libros, autores, subrayados y notas", text: $query, focused: $focused,
                                onSubmit: remember)
                        .padding(.top, Theme.Space.l)
                    if term.isEmpty {
                        start
                    } else {
                        let found = (books: books, highlights: highlights, notes: notes)
                        if found.books.isEmpty && found.highlights.isEmpty && found.notes.isEmpty {
                            EmptyState(title: "Sin resultados para «\(term)»",
                                       message: "Busqué cada palabra en títulos, autores, series y etiquetas, en tus subrayados y en tus notas. Para buscar dentro de un libro, ábrelo y toca la lupa.")
                        } else {
                            results(found)
                        }
                    }
                }
                .screenContent()
            }
            // Al deslizar se esconde el teclado; y no se abre solo (se ven tus recientes).
            .scrollDismissesKeyboard(.immediately)
            .saveShelfAlert(query: $savingShelf) { model.library.saveShelf($0) }
            .screen()
            .onAppear {
                recents = RecentSearches.load(nil)
                #if DEBUG
                // Capturas: `-screenshot.query palabra` escribe la búsqueda.
                if let preset = UserDefaults.standard.string(forKey: "screenshot.query") { query = preset }
                #endif
            }
            // Lo que buscaste queda entre tus recientes al dejar de escribir.
            .task(id: term) {
                guard term.count >= 2 else { return }
                try? await Task.sleep(for: .seconds(Theme.Reader.searchRemember))
                guard !Task.isCancelled else { return }
                remember()
            }
        }
    }

    private func remember() {
        guard term.count >= 2 else { return }
        recents = RecentSearches.add(term, count: books.count + highlights.count + notes.count, for: nil)
    }

    // MARK: Vacía

    @ViewBuilder
    private var start: some View {
        if recents.isEmpty && recentlyOpened.isEmpty {
            EmptyState(title: "Busca en tu Gabinete",
                       message: "Encuentra un libro por su título, su autor o su serie, o una idea entre tus subrayados y tus notas. Con «autor:» o «serie:» ves solo los de ese autor o esa serie.")
        }
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Búsquedas recientes")
                    .padding(.bottom, Theme.Space.xs)
                ForEach(recents) { item in
                    RecentSearchRow(text: item.text, count: item.count) { query = item.text }
                }
                TextAction(title: "Borrar recientes") {
                    RecentSearches.clear(nil)
                    recents = []
                }
            }
            .padding(.top, Theme.Space.xl)
        }
        if !recentlyOpened.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Abiertos hace poco")
                    .padding(.bottom, Theme.Space.xs)
                ForEach(recentlyOpened) { book in
                    NavigationLink(value: book) {
                        BookRow(book: book, detail: "\(book.author) · \(book.progress.percentText) leído")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Space.xl)
        }
    }

    // MARK: Resultados

    private func results(_ found: (books: [ShelfBook], highlights: [Annotation], notes: [Note])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summary(found))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, Theme.Space.l)
            if !found.books.isEmpty {
                TextAction(title: "Guardar estos libros como estante") { savingShelf = term }
            }
            if !found.books.isEmpty {
                section("Libros") {
                    ForEach(found.books) { book in
                        NavigationLink(value: book) { BookRow(book: book) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !found.highlights.isEmpty {
                section("Tus subrayados") {
                    let shown = showsAllHighlights ? found.highlights : Array(found.highlights.prefix(Theme.Reader.foundHighlights))
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        ForEach(shown) { highlight in
                            Button { model.openPassage(annotationID: highlight.id) } label: {
                                QuoteBlock(label: label(for: highlight), text: highlight.quote, note: highlight.note, match: term)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Abre el libro en este pasaje")
                        }
                    }
                    .padding(.top, Theme.Space.s)
                    if found.highlights.count > shown.count {
                        TextAction(title: "Ver \(found.highlights.count.counted("subrayado", "subrayados"))") { showsAllHighlights = true }
                    }
                }
            }
            if !found.notes.isEmpty {
                section("Tus notas") {
                    ForEach(found.notes) { note in
                        NavigationLink(value: NoteRef(fileName: note.fileName)) { NoteRow(note: note, match: term) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: term) { _, _ in showsAllHighlights = false }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title)
                .padding(.bottom, Theme.Space.xs)
            content()
        }
        .padding(.top, Theme.Space.xl)
    }

    /// «1 libro · 4 subrayados · 1 nota».
    private func summary(_ found: (books: [ShelfBook], highlights: [Annotation], notes: [Note])) -> String {
        func count(_ n: Int, _ one: String, _ many: String) -> String? { n == 0 ? nil : n.counted(one, many) }
        return [count(found.books.count, "libro", "libros"),
                count(found.highlights.count, "subrayado", "subrayados"),
                count(found.notes.count, "nota", "notas")].compactMap { $0 }.joined(separator: " · ")
    }

    /// «Agentes del imperio · 12 nov».
    private func label(for highlight: Annotation) -> String {
        let title = model.shelfBook(id: highlight.bookID.uuidString)?.title ?? highlight.bookTitle ?? "Sin título"
        return "\(title) · \(highlight.createdAt.es(.dateTime.day().month(.abbreviated)))"
    }
}
