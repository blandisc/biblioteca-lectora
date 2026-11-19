import SwiftUI

/// Buscar, en su propio espacio del dock. Mismo título y margen que las demás pantallas.
struct SearchScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @FocusState private var focused: Bool

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
                    // Campo propio bajo el título: el del sistema (`.searchable`) quedaba
                    // escondido con la barra de navegación y no había dónde escribir.
                    SearchField(prompt: "Títulos, autores y series", text: $query, focused: $focused, onSubmit: {})
                        .padding(.top, Theme.Space.m)
                    if query.isEmpty {
                        EmptyState(title: "Busca en tu biblioteca",
                                   message: "Encuentra cualquier libro de tu Gabinete por su título, su autor o su serie.")
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
            .navigationDestination(for: NoteRef.self) { NoteScreen(ref: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear { if query.isEmpty { focused = true } }
        }
    }
}
