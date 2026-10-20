import SwiftUI

/// Búsqueda en títulos y autores (después también en el texto y tus subrayados).
struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .editorial

    private var results: [ShelfBook] {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return [] }
        return model.shelf.filter {
            $0.title.localizedStandardContains(term) || $0.author.localizedStandardContains(term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView("Busca en tu biblioteca", systemImage: "magnifyingglass",
                                           description: Text("Títulos y autores. Pronto, también el texto de tus libros y tus subrayados."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { book in
                        NavigationLink(value: book) {
                            HStack(spacing: 12) {
                                ShelfCover(book: book).frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title).font(.body.weight(.semibold)).lineLimit(1)
                                    Text(book.author).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((style == .editorial ? Theme.Editorial.paper : Theme.groupedBackground).ignoresSafeArea())
            .navigationTitle("Buscar")
            .navigationDestination(for: ShelfBook.self) { BookDetailView(book: $0) }
            .searchable(text: $query, prompt: "Títulos y autores")
        }
    }
}
