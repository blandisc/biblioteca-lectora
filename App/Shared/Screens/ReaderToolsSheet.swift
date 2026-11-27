import LectoraCore
import SwiftUI

/// Herramientas del lector, en una hoja: el índice del libro, buscar en el
/// libro y tus marcas en él (marcadores y subrayados). Tocar algo lleva ahí y cierra la hoja.
struct ReaderToolsSheet: View {
    enum Part: String, CaseIterable, Identifiable {
        case contents = "Índice"
        case search = "Buscar"
        case highlights = "Marcas"
        var id: Self { self }
    }

    @ObservedObject var controller: ReaderController
    let bookID: UUID?
    @State var part: Part
    @ObservedObject private var annotations = AnnotationStore.shared
    @ObservedObject private var library = LibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var recents: [RecentSearches.Item] = []

    private var highlights: [Annotation] {
        guard let bookID else { return [] }
        return annotations.annotations(forBook: bookID)
    }

    private var bookmarks: [Bookmark] {
        bookID.map { library.bookmarks(for: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FilterBar(items: Part.allCases, selection: $part) { $0.rawValue }
                    Group {
                        switch part {
                        case .contents: contents
                        case .search: search
                        case .highlights: highlightList
                        }
                    }
                    .padding(.top, Theme.Space.l)
                }
                .screenContent()
            }
            // Al deslizar la lista se esconde el teclado: caben más resultados.
            .scrollDismissesKeyboard(.immediately)
            .pushedScreen(controller.title ?? "Libro")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Volver al libro") { dismiss() }
                }
            }
            .onAppear {
                query = controller.searchedQuery
                recents = RecentSearches.load(bookID)
                if part == .search { searchFocused = true }
            }
            .onChange(of: controller.searchProgress == nil) { _, _ in recents = RecentSearches.load(bookID) }
        }
        .presentationDetents([.large])
    }

    // MARK: Índice

    @ViewBuilder
    private var contents: some View {
        if controller.contents.isEmpty {
            EmptyState(title: "Este libro no trae índice", message: "Puedes moverte con la barra de avance o buscar una palabra.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(controller.contents) { entry in
                    Button {
                        if let href = entry.href { controller.goTo(target: href) }
                        dismiss()
                    } label: {
                        ContentsRow(label: entry.label, depth: entry.depth, isCurrent: isCurrent(entry))
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.href == nil)
                }
            }
        }
    }

    private func isCurrent(_ entry: ReaderController.ContentsEntry) -> Bool {
        guard let current = controller.location?.chapterHref, let href = entry.href else {
            return entry.label == controller.location?.chapter
        }
        return href == current
    }

    // MARK: Buscar

    /// Los resultados juntos por capítulo, en el orden del libro.
    private struct ChapterGroup: Identifiable {
        let chapter: String
        var results: [ReaderController.SearchResult]
        var id: Int { results.first?.id ?? 0 }
    }

    private var groups: [ChapterGroup] {
        controller.searchResults.reduce(into: []) { groups, result in
            if groups.last?.chapter == result.chapter {
                groups[groups.count - 1].results.append(result)
            } else {
                groups.append(ChapterGroup(chapter: result.chapter, results: [result]))
            }
        }
    }

    /// El primer resultado que queda después de donde vas: ahí va «Aquí vas».
    private var nextAhead: Int? {
        guard let here = controller.location?.fraction else { return nil }
        let results = controller.searchResults
        guard let first = results.first, first.fraction <= here else { return nil }
        return results.first { $0.fraction > here }?.id
    }

    private var searchIsEmpty: Bool {
        !controller.searchedQuery.isEmpty && controller.searchProgress == nil && controller.searchResults.isEmpty
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SearchField(prompt: "Buscar en el libro", text: $query, focused: $searchFocused,
                        onSubmit: { controller.search(query) },
                        onClear: { controller.clearSearch() })
            if let progress = controller.searchProgress {
                // Cuánto lleva: los resultados van apareciendo abajo mientras busca.
                HStack(spacing: Theme.Space.s) {
                    ThinProgress(value: progress)
                    Text("\(progress.percentText) del libro · \(foundText)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryInk)
                        .layoutPriority(1)
                }
            } else if !controller.searchResults.isEmpty {
                Text(resultsLine)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if searchIsEmpty && controller.searchedQuery.count >= 2 {
                EmptyState(title: "No aparece «\(controller.searchedQuery)» en este libro",
                           message: "Busqué en todo el libro, sin importar acentos ni mayúsculas. Revisa cómo se escribe o prueba con una sola palabra.")
            }
            if controller.searchResults.isEmpty && controller.searchProgress == nil {
                recentList
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    SearchChapterHeading(title: group.chapter, count: group.results.count)
                    ForEach(group.results) { result in
                        if result.id == nextAhead, let page = controller.location?.page {
                            HereMark(text: "Aquí vas · pág. \(page)")
                        }
                        Button {
                            if let index = controller.searchResults.firstIndex(of: result) {
                                controller.goToResult(index)
                            }
                            dismiss()
                        } label: {
                            SearchResultRow(before: result.before, match: result.match, after: result.after,
                                            place: place(of: result))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(for: result))
                    }
                }
            }
        }
        // Busca sola al dejar de escribir (desde tres letras); la tecla «Buscar» también.
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= Theme.Reader.searchMinLetters, text != controller.searchedQuery else { return }
            try? await Task.sleep(for: .seconds(Theme.Reader.searchPause))
            guard !Task.isCancelled else { return }
            controller.search(text)
        }
    }

    /// Las búsquedas recientes de este libro (sin lo que se está buscando ahora).
    @ViewBuilder
    private var recentList: some View {
        let shown = recents.filter { $0.text != controller.searchedQuery }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Búsquedas recientes")
                    .padding(.top, Theme.Space.l)
                    .padding(.bottom, Theme.Space.xs)
                ForEach(shown) { item in
                    RecentSearchRow(text: item.text, count: item.count) {
                        query = item.text
                        controller.search(item.text)
                    }
                }
                Button("Borrar recientes") {
                    RecentSearches.clear(bookID)
                    recents = []
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .frame(minHeight: Theme.Size.tapTarget)
                .buttonStyle(.plain)
            }
        }
    }

    private func place(of result: ReaderController.SearchResult) -> String {
        if let page = result.page { return "pág. \(page)" }
        return result.fraction.percentText
    }

    private func accessibilityLabel(for result: ReaderController.SearchResult) -> String {
        let number = (controller.searchResults.firstIndex(of: result) ?? 0) + 1
        let page = result.page.map { ", página \($0)" } ?? ""
        return "Resultado \(number) de \(controller.searchResults.count), \(result.chapter)\(page). "
            + result.before + result.match + result.after
    }

    private var foundText: String {
        controller.searchResults.count.counted("encontrado", "encontrados")
    }

    private var resultsLine: String {
        let count = controller.searchResults.count, chapters = groups.count
        if count >= 300 { return "Los primeros 300 resultados: prueba con más palabras." }
        let results = count.counted("resultado", "resultados")
        return chapters <= 1 ? results : "\(results) en \(chapters.counted("capítulo", "capítulos"))"
    }

    // MARK: Marcas

    @ViewBuilder
    private var highlightList: some View {
        if highlights.isEmpty && bookmarks.isEmpty {
            EmptyState(title: "Sin marcas en este libro",
                       message: "Toca la cinta arriba para marcar una página, o mantén el dedo sobre el texto y elige «Subrayar». Aquí las encuentras para volver.")
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                if !bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader("Marcadores")
                        ForEach(bookmarks) { mark in
                            Button {
                                controller.goTo(target: mark.cfi)
                                dismiss()
                            } label: {
                                ContentsRow(label: "\(mark.fraction.percentText) · \(mark.excerpt ?? "Página marcada")")
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { library.removeBookmark(id: mark.id) } label: {
                                    Label("Quitar marcador", systemImage: "bookmark.slash")
                                }
                            }
                        }
                    }
                }
                if !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        SectionHeader("Subrayados")
                        ForEach(highlights) { highlight in
                            Button {
                                if let cfi = highlight.cfi {
                                    controller.goTo(target: cfi)
                                    dismiss()
                                }
                            } label: {
                                QuoteBlock(label: label(for: highlight), text: highlight.quote, note: highlight.note)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let cfi = highlight.cfi {
                                    Button(role: .destructive) { controller.removeHighlight(cfi: cfi) } label: {
                                        Label("Borrar subrayado", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // El primer rótulo a la misma altura que la primera entrada del Índice.
            .padding(.top, Theme.Space.rowY)
        }
    }

    /// «12 nov», y de dónde vino si no se encontró su lugar en este libro.
    private func label(for highlight: Annotation) -> String {
        let day = highlight.createdAt.esDayMonth
        guard highlight.cfi == nil else { return day }
        let origin = highlight.source == "calibre" ? "de Calibre" : "de Readwise"
        return "\(day) · \(origin), sin lugar en este libro"
    }
}

/// Las últimas búsquedas en cada libro (y, sin libro, las de la pestaña Buscar),
/// guardadas solo en este dispositivo.
enum RecentSearches {
    struct Item: Codable, Identifiable, Equatable {
        let text: String
        let count: Int
        var id: String { text }
    }

    private static func key(_ bookID: UUID?) -> String? { bookID.map { "reader.searches.\($0.uuidString)" } ?? "search.recent.library" }

    static func load(_ bookID: UUID?) -> [Item] {
        guard let key = key(bookID), let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    /// La más nueva primero, sin repetir, hasta `Theme.Reader.recentSearches`.
    static func add(_ text: String, count: Int, for bookID: UUID?) -> [Item] {
        guard let key = key(bookID) else { return [] }
        var items = load(bookID).filter { $0.text.localizedCaseInsensitiveCompare(text) != .orderedSame }
        items.insert(Item(text: text, count: count), at: 0)
        items = Array(items.prefix(Theme.Reader.recentSearches))
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key)
        return items
    }

    static func clear(_ bookID: UUID?) {
        guard let key = key(bookID) else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}
