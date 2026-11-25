import LectoraCore
import SwiftUI

/// Buscar, en su propio espacio del dock. Mismo título y margen que las demás pantallas.
/// Busca en tus libros (título, autor, serie), tus subrayados y tus notas.
struct SearchScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var recents: [RecentSearches.Item] = []
    /// «Ver los 12 subrayados»: de inicio solo los primeros.
    @State private var showsAllHighlights = false

    private var term: String { query.trimmingCharacters(in: .whitespaces) }

    private var books: [ShelfBook] {
        guard !term.isEmpty else { return [] }
        return model.shelf.filter {
            $0.title.localizedStandardContains(term) || $0.author.localizedStandardContains(term)
                || ($0.series?.localizedStandardContains(term) ?? false)
        }
    }

    private var highlights: [Annotation] {
        guard term.count >= 2 else { return [] }
        return model.annotations.allAnnotations().filter {
            $0.quote.localizedStandardContains(term) || ($0.note?.localizedStandardContains(term) ?? false)
        }
    }

    private var notes: [Note] {
        guard term.count >= 2 else { return [] }
        return model.notes.notes.filter { $0.text.localizedStandardContains(term) || $0.fileName.localizedStandardContains(term) }
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
                        .padding(.top, Theme.Space.m)
                    if term.isEmpty {
                        start
                    } else {
                        let found = (books: books, highlights: highlights, notes: notes)
                        if found.books.isEmpty && found.highlights.isEmpty && found.notes.isEmpty {
                            EmptyState(title: "Sin resultados para «\(term)»",
                                       message: "Busqué en títulos, autores y series, en tus subrayados y en tus notas. Para buscar dentro de un libro, ábrelo y toca la lupa.")
                        } else {
                            results(found)
                        }
                    }
                }
                .screenContent()
            }
            // Al deslizar se esconde el teclado; y no se abre solo (se ven tus recientes).
            .scrollDismissesKeyboard(.immediately)
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
                       message: "Encuentra un libro por su título, su autor o su serie, o una frase entre tus subrayados y tus notas.")
        }
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Búsquedas recientes")
                    .padding(.bottom, Theme.Space.xs)
                ForEach(recents) { item in
                    RecentSearchRow(text: item.text, count: item.count) { query = item.text }
                }
                Button("Borrar recientes") {
                    RecentSearches.clear(nil)
                    recents = []
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .frame(minHeight: Theme.Size.tapTarget)
                .buttonStyle(.plain)
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
                .padding(.top, Theme.Space.m)
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
                        Button("Ver los \(found.highlights.count) subrayados") { showsAllHighlights = true }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .frame(minHeight: Theme.Size.tapTarget)
                            .buttonStyle(.plain)
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
        func count(_ n: Int, _ one: String, _ many: String) -> String? { n == 0 ? nil : "\(n) \(n == 1 ? one : many)" }
        return [count(found.books.count, "libro", "libros"),
                count(found.highlights.count, "subrayado", "subrayados"),
                count(found.notes.count, "nota", "notas")].compactMap { $0 }.joined(separator: " · ")
    }

    /// «Agentes del imperio · 12 nov».
    private func label(for highlight: Annotation) -> String {
        let title = model.shelfBook(id: highlight.bookID.uuidString)?.title ?? highlight.bookTitle
        return "\(title) · \(highlight.createdAt.es(.dateTime.day().month(.abbreviated)))"
    }
}
