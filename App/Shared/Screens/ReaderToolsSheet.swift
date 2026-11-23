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
                    .padding(.top, Theme.Space.m)
                }
                .screenContent()
            }
            .pushedScreen(controller.title ?? "Libro")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .onAppear {
                query = controller.searchedQuery
                if part == .search { searchFocused = true }
            }
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

    private var search: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SearchField(prompt: "Buscar en el libro", text: $query, focused: $searchFocused,
                        onSubmit: { controller.search(query) },
                        onClear: { controller.clearSearch() })
            if let progress = controller.searchProgress {
                HStack(spacing: Theme.Space.s) {
                    ThinProgress(value: progress)
                    Text("Buscando…").font(.footnote).foregroundStyle(Theme.secondaryInk)
                }
            } else if !controller.searchedQuery.isEmpty {
                Text(resultsLine)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            LazyVStack(spacing: 0) {
                ForEach(controller.searchResults) { result in
                    Button {
                        controller.goTo(target: result.cfi)
                        dismiss()
                    } label: {
                        SearchResultRow(chapter: result.chapter, before: result.before, match: result.match, after: result.after)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsLine: String {
        switch controller.searchResults.count {
        case 0: "Nada coincide con «\(controller.searchedQuery)»."
        case 1: "1 resultado"
        case 300...: "Más de 300 resultados: prueba con más palabras."
        default: "\(controller.searchResults.count) resultados"
        }
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
                        SectionLabel(text: "Marcadores")
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
                        SectionLabel(text: "Subrayados")
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
        let day = highlight.createdAt.es(.dateTime.day().month(.abbreviated))
        guard highlight.cfi == nil else { return day }
        let origin = highlight.source == "calibre" ? "de Calibre" : "de Readwise"
        return "\(day) · \(origin), sin lugar en este libro"
    }
}
