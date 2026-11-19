import LectoraCore
import SwiftUI

/// Herramientas del lector, en una hoja: el índice del libro, buscar en el
/// libro y tus subrayados de este libro. Tocar algo lleva ahí y cierra la hoja.
struct ReaderToolsSheet: View {
    enum Part: String, CaseIterable, Identifiable {
        case contents = "Índice"
        case search = "Buscar"
        case highlights = "Subrayados"
        var id: Self { self }
    }

    @ObservedObject var controller: ReaderController
    let bookID: UUID?
    @State var part: Part
    @ObservedObject private var annotations = AnnotationStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var highlights: [Annotation] {
        guard let bookID else { return [] }
        return annotations.annotations(forBook: bookID).filter { $0.cfi != nil }
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
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(controller.title ?? "Libro")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }.foregroundStyle(Theme.accent)
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

    // MARK: Subrayados

    @ViewBuilder
    private var highlightList: some View {
        if highlights.isEmpty {
            EmptyState(title: "Sin subrayados en este libro",
                       message: "Mantén el dedo sobre el texto y elige «Subrayar». Aquí los encuentras para volver a cada pasaje.")
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                ForEach(highlights) { highlight in
                    Button {
                        if let cfi = highlight.cfi { controller.goTo(target: cfi) }
                        dismiss()
                    } label: {
                        QuoteBlock(label: highlight.createdAt.es(.dateTime.day().month(.abbreviated)), text: highlight.quote, note: highlight.note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            if let cfi = highlight.cfi { controller.removeHighlight(cfi: cfi) }
                        } label: { Label("Borrar subrayado", systemImage: "trash") }
                    }
                }
            }
        }
    }
}
