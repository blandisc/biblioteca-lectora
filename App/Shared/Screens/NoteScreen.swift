import LectoraCore
import SwiftUI

/// Nota a abrir: una que ya existe (`fileName`) o una nueva con un borrador.
struct NoteRef: Hashable {
    var fileName: String?
    var draft = ""
    /// Cada «Nota nueva» es una pantalla distinta.
    var token = UUID()

    static func new(draft: String = "") -> NoteRef { NoteRef(fileName: nil, draft: draft) }
}

/// Una nota: se lee con sus enlaces y se escribe en Markdown con «Editar».
/// Al escribir `[[` sugiere libros de tu biblioteca. Se guarda al tocar «Listo»
/// y al salir.
struct NoteScreen: View {
    let ref: NoteRef
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var notes = NotesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
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
        let books = term.isEmpty ? Array(model.shelf.prefix(20)) : model.shelf.filter {
            $0.title.localizedStandardContains(term) || $0.author.localizedStandardContains(term)
        }
        return Array(books.prefix(4))
    }

    var body: some View {
        content
            .background(Theme.paper.ignoresSafeArea())
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if editing {
                        Button("Listo") { finishEditing() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accent)
                    } else {
                        Menu("Editar") {
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
            .confirmationDialog("¿Borrar «\(note?.title ?? "esta nota")»?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Borrar nota", role: .destructive) { deleteNote() }
            } message: {
                Text("Se borra el archivo de Gabinete/Notas.")
            }
            .alert("No se pudo guardar la nota", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
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
            .padding(.top, Theme.Space.m)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    location
                    NoteBody(text: text)
                }
                .screenContent()
            }
            .onTapGesture(count: 2) { startEditing() }
        }
    }

    /// «Hoy · Notas/El silencio en Rulfo.md»
    private var location: some View {
        Text(fileName.map { "\(NoteRow.day(note?.modifiedAt ?? Date())) · \(CabinetLocation.notesFolder)/\($0).md" }
             ?? "Nota nueva · se guarda en \(CabinetLocation.notesFolder)")
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
            text = existing.text
        } else {
            text = ref.draft.isEmpty ? "# " : ref.draft
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
            let saved = try notes.save(text: text, fileName: fileName)
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
