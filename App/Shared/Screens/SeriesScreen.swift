import SwiftUI

/// Los libros de una serie, en orden.
struct SeriesScreen: View {
    let series: SeriesRef
    @EnvironmentObject private var model: AppModel

    private var books: [ShelfBook] {
        model.shelf.filter(series.contains)
            .sorted { ($0.seriesIndex ?? 0) < ($1.seriesIndex ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: series.name)
                Text("\(books.count) libros")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, Theme.Space.xs)
                LazyVStack(spacing: 0) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            BookRow(book: book, detail: book.seriesIndex.map { "Libro \(ShelfBook.number($0)) · \(book.author)" })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Theme.Space.m)
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
