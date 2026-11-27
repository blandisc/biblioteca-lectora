import LectoraCore
import SwiftUI

/// Un estante (CB-1): los libros que cumplen su búsqueda guardada, que se llena sola.
/// Desde Editar se renombra o se borra (borrar el estante no borra ningún libro).
struct SavedShelfScreen: View {
    let ref: ShelfRef
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false

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
                Text("\(books.count.counted("libro", "libros")) · \(shelf?.query ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, Theme.Space.xs)
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
                    Button {
                        newName = shelf?.name ?? ""
                        renaming = true
                    } label: { Label("Renombrar estante", systemImage: "pencil") }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Borrar estante", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Renombrar estante", isPresented: $renaming) {
            TextField("Nombre", text: $newName)
            Button("Guardar nombre") {
                guard var shelf, !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                shelf.name = newName.trimmingCharacters(in: .whitespaces)
                model.library.saveShelf(shelf)
            }
            Button("Dejar como está", role: .cancel) {}
        }
        .confirmationDialog("¿Borrar el estante «\(shelf?.name ?? "")»?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Borrar estante", role: .destructive) {
                model.library.removeShelf(id: ref.id)
                dismiss()
            }
        } message: {
            Text("Tus libros se quedan donde están; solo se va el estante.")
        }
    }
}

/// «Guardar como estante» (CB-1): pide el nombre, con uno propuesto a partir de la búsqueda.
struct SaveShelfAlert: ViewModifier {
    @Binding var query: String?
    let save: (SavedShelf) -> Void
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Guardar como estante", isPresented: Binding(
                get: { query != nil }, set: { if !$0 { query = nil } }
            )) {
                TextField("Nombre", text: $name)
                Button("Guardar estante") {
                    if let query, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        save(SavedShelf(name: name, query: query))
                    }
                    query = nil
                }
                Button("Dejar sin guardar", role: .cancel) { query = nil }
            } message: {
                Text("Se llena solo con los libros que cumplan «\(query ?? "")».")
            }
            .onChange(of: query) { _, new in
                if let new { name = SavedShelf.suggestedName(for: new) }
            }
    }
}

extension View {
    func saveShelfAlert(query: Binding<String?>, save: @escaping (SavedShelf) -> Void) -> some View {
        modifier(SaveShelfAlert(query: query, save: save))
    }
}
