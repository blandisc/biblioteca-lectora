import LectoraCore
import SwiftUI

/// Nota a abrir: una que ya existe (`fileName`) o una nueva con un borrador.
struct NoteRef: Hashable {
    var fileName: String?
    var draft = ""
    /// Abre una nota que ya existe directo en el editor («Escribir sobre ella»).
    var writes = false
    /// Cada «Nota nueva» es una pantalla distinta.
    var token = UUID()

    static func new(draft: String = "") -> NoteRef { NoteRef(fileName: nil, draft: draft) }
}

extension NoteRef: Identifiable {
    var id: UUID { token }
}

/// Una nota: se lee con sus enlaces y se escribe en Markdown con «Editar».
/// Al escribir `[[` sugiere libros de tu biblioteca. Se guarda al tocar «Listo»
/// y al salir.
struct NoteScreen: View {
    let ref: NoteRef
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var notes = NotesStore.shared
    @Environment(\.dismiss) private var dismiss
    /// Lo que se ve y se escribe: sin los comentarios de la nota (`hidden`).
    @State private var text = ""
    /// Los comentarios (`<!-- … -->`, como la marca de su sesión): no se ven ni se pueden borrar
    /// sin querer; se vuelven a poner al guardar (auditoría 3).
    @State private var hidden: [String] = []
    @State private var fileName: String?
    @State private var editing = false
    @State private var loaded = false
    @State private var linkedBook: ShelfBook?
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @FocusState private var focused: Bool

    private var note: Note? { fileName.flatMap(notes.note(fileName:)) }

    /// Libros para el `[[` que se está escribiendo.
    private var suggestions: [ShelfBook] {
        guard editing, let query = NoteMarkdown.openLinkQuery(in: text) else { return [] }
        let term = query.trimmingCharacters(in: .whitespaces)
        let books = term.isEmpty ? Array(model.shelf.prefix(Theme.Lists.linkShelf)) : model.shelf.filter {
            $0.title.localizedStandardContains(term) || $0.author.localizedStandardContains(term)
        }
        return Array(books.prefix(Theme.Lists.linkSuggestions))
    }

    var body: some View {
        content
            .pushedScreen()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if editing {
                        BarButton("Terminar la nota") { finishEditing() }
                            .fontWeight(.semibold)
                    } else {
                        BarMenu(title: "Editar") {
                            Button { startEditing() } label: { Label("Escribir", systemImage: "pencil") }
                            if fileName != nil {
                                Button(role: .destructive) { confirmingDelete = true } label: {
                                    Label("Borrar nota", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !suggestions.isEmpty { suggestionList }
            }
            .environment(\.openURL, OpenURLAction(handler: open))
            .navigationDestination(item: $linkedBook) { BookDetailScreen(book: $0) }
            .question("¿Borrar «\((note?.title ?? "esta nota").isolated)»?", isPresented: $confirmingDelete) {
                Button("Borrarla", role: .destructive) { deleteNote() }
                Button("Conservarla", role: .cancel) {}
            } message: {
                Text("Borro su archivo de la carpeta Notas de tu Gabinete. Tus libros y subrayados se quedan.")
            }
            .errorAlert("No pude guardar la nota", message: $errorMessage, back: "Seguir editando")
            .onAppear(perform: load)
            .onDisappear { if editing { save() } }
    }

    @ViewBuilder
    private var content: some View {
        if editing {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                location
                TextEditor(text: $text)
                    .font(.prose)
                    .lineSpacing(Theme.Space.xs)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .foregroundStyle(Theme.ink)
            }
            .gutter()
            .padding(.top, Theme.Space.l)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    location
                    NoteBody(text: text) { model.shelfBook(titled: $0) != nil }
                }
                .screenContent()
            }
            .onTapGesture(count: 2) { startEditing() }
        }
    }

    /// Cuándo la escribiste («Hoy»), no su archivo: «Notas/El silencio en Rulfo.md» es cosa del
    /// disco, no de quien lee la nota.
    private var location: some View {
        Text(fileName == nil ? "Nota nueva · la guardo en tu carpeta de notas"
             : NoteRow.day(note?.modifiedAt ?? Date()))
            .font(.footnote)
            .foregroundStyle(Theme.tertiaryInk)
            .lineLimit(1)
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Enlazar un libro de tu biblioteca")
                .font(.caption)
                .foregroundStyle(Theme.tertiaryInk)
                .padding(.top, Theme.Space.s)
            ForEach(suggestions) { book in
                Button {
                    text = NoteMarkdown.completingLink(in: text, with: book.title)
                } label: {
                    BookRow(book: book, detail: book.author)
                }
                .buttonStyle(.plain)
            }
        }
        .gutter()
        .background(Theme.paper)
        .overlay(alignment: .top) { Hairline() }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let name = ref.fileName, let existing = notes.note(fileName: name) {
            fileName = name
            (text, hidden) = NoteMarkdown.editable(existing.text)
            if ref.writes { startEditing() }
        } else {
            (text, hidden) = NoteMarkdown.editable(ref.draft.isEmpty ? "# " : ref.draft)
            startEditing()
        }
    }

    private func startEditing() {
        editing = true
        focused = true
    }

    private func finishEditing() {
        save()
        focused = false
        if fileName == nil {
            dismiss()
        } else {
            editing = false
        }
    }

    private func save() {
        do {
            // Vacía se borra, también la de una sesión: la marca no vuelve a una nota sin nada (auditoría 4).
            let saved = try notes.save(text: NoteMarkdown.savedText(text, restoring: hidden), fileName: fileName)
            fileName = saved?.fileName
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNote() {
        guard let fileName else { return }
        do {
            try notes.delete(fileName: fileName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// `[[Libro]]` abre su ficha; «ir al pasaje», el libro en ese subrayado.
    private func open(_ url: URL) -> OpenURLAction.Result {
        switch NoteMarkdown.target(of: url) {
        case .book(let title):
            linkedBook = model.shelfBook(titled: title)
            return .handled
        case .passage(let id):
            model.openPassage(annotationID: id)
            return .handled
        case nil:
            return .systemAction
        }
    }
}
