import SwiftUI

/// Buscar, en su propio espacio del dock. Mismo título y margen que las demás pantallas.
struct SearchScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var results: [ShelfBook] {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return [] }
        return model.shelf.filter {
            $0.title.localizedStandardContains(term) || $0.author.localizedStandardContains(term)
                || ($0.series?.localizedStandardContains(term) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Buscar")
                    if query.isEmpty {
                        EmptyState(title: "Busca en tu biblioteca",
                                   message: "Títulos, autores y series. Pronto, también el texto de tus libros y tus subrayados.")
                    } else if results.isEmpty {
                        EmptyState(title: "Sin resultados", message: "Nada coincide con «\(query)».")
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { book in
                                NavigationLink(value: book) { BookRow(book: book) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, Theme.Space.m)
                    }
                }
                .screenContent()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationDestination(for: ShelfBook.self) { BookDetailScreen(book: $0) }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $query, prompt: "Títulos, autores y series")
        }
    }
}
