import LectoraCore
import SwiftUI

/// Un estante (CB-1): los libros que cumplen su búsqueda guardada, que se llena sola.
/// Desde Editar se renombra o se borra (borrar el estante no borra ningún libro).
struct SavedShelfScreen: View {
    let ref: ShelfRef
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: SavedShelf?
    @State private var deleting: SavedShelf?

    private var shelf: SavedShelf? { model.library.shelf(id: ref.id) }

    private var books: [ShelfBook] {
        guard let shelf else { return [] }
        let found = Set(model.library.books.filter(shelf.contains).map(\.id.uuidString))
        return model.shelf.filter { found.contains($0.id) }
            .sorted { $0.sortTitle.localizedStandardCompare($1.sortTitle) == .orderedAscending }
    }

    var body: some View {
        let books = self.books
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: shelf?.name ?? "Estante")
                CountLine(text: "\(books.count.counted("libro", "libros")) · \(shelf?.query ?? "")")
                if books.isEmpty {
                    EmptyState(title: "Este estante está vacío",
                               message: "Se llena solo con los libros que cumplen «\(shelf?.query ?? "")».")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(books) { book in
                            NavigationLink(value: book) { BookRow(book: book) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Theme.Space.l)
                }
            }
            .screenContent()
        }
        .pushedScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Editar") {
                    Button { renaming = shelf } label: { Label("Renombrar estante", systemImage: "character.cursor.ibeam") }
                    Button(role: .destructive) { deleting = shelf } label: {
                        Label("Borrar estante", systemImage: "trash")
                    }
                }
            }
        }
        .renameShelfAlert($renaming) { model.library.saveShelf($0) }
        .deleteShelfConfirmation($deleting) { _ in
            model.library.removeShelf(id: ref.id)
            dismiss()
        }
    }
}
