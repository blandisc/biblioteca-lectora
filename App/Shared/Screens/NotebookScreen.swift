import LectoraCore
import SwiftUI

/// Cuaderno: tus subrayados, los más recientes primero o agrupados por libro.
struct NotebookScreen: View {
    enum Part: String, CaseIterable, Identifiable {
        case recent = "Recientes"
        case books = "Libros"
        case topics = "Temas"
        var id: Self { self }
    }

    @EnvironmentObject private var model: AppModel
    @State private var part: Part = .recent
    @State private var showsAccount = false

    private var highlights: [Annotation] { model.annotations.allAnnotations() }

    private func shelfBook(_ id: UUID) -> ShelfBook? {
        model.shelfBook(id: id.uuidString)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Cuaderno") {
                        Button { showsAccount = true } label: { Image(systemName: "person.crop.circle") }
                            .accessibilityLabel("Cuenta, conexiones y apariencia")
                    }
                    FilterBar(items: Part.allCases, selection: $part) { $0.rawValue }
                        .padding(.top, Theme.Space.m)

                    Group {
                        switch part {
                        case .recent: recent
                        case .books: byBook
                        case .topics:
                            EmptyState(title: "Temas", message: "Cuando conectes la IA, agrupará tus subrayados por idea, aunque vengan de libros distintos.")
                        }
                    }
                    .padding(.top, Theme.Space.l)
                }
                .screenContent()
            }
            .screen()
            .sheet(isPresented: $showsAccount) { SettingsScreen() }
        }
    }

    @ViewBuilder
    private var recent: some View {
        if highlights.isEmpty {
            EmptyState(title: "Sin subrayados todavía",
                       message: "Mantén el dedo sobre el texto mientras lees y elige «Subrayar». Lo que marques aparece aquí.")
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                ForEach(highlights) { highlight in
                    QuoteBlock(label: shelfBook(highlight.bookID)?.title, text: highlight.quote, note: highlight.note)
                }
            }
        }
    }

    @ViewBuilder
    private var byBook: some View {
        let groups = Dictionary(grouping: highlights, by: \.bookID)
            .compactMap { id, items in shelfBook(id).map { BookCount(book: $0, count: items.count) } }
            .sorted { $0.book.title.localizedStandardCompare($1.book.title) == .orderedAscending }
        if groups.isEmpty {
            EmptyState(title: "Sin libros subrayados", message: "Aquí verás cada libro con el número de subrayados que tiene.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    NavigationLink(value: group.book) {
                        BookRow(book: group.book, detail: group.book.author) {
                            Text("\(group.count)").monospacedDigit().foregroundStyle(Theme.pencil)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BookCount: Identifiable {
    let book: ShelfBook
    let count: Int
    var id: String { book.id }
}
