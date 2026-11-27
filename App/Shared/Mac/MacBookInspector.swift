#if os(macOS)
import LectoraCore
import SwiftUI

/// La ficha a la derecha de la tabla (MG-1). Con un libro, todos sus datos; con varios,
/// lo que cambies se aplica a todos (lo que dejes en blanco no se toca).
struct MacBookInspector: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var library: LibraryStore
    let ids: Set<UUID>

    @State private var draft = Draft()
    @State private var loaded = Draft()
    @State private var errorMessage: String?
    /// Mientras se buscan los datos en internet: la ficha lo dice, no corre en silencio (C8).
    @State private var finding = false

    private var books: [Book] { books(ids) }

    private func books(_ ids: Set<UUID>) -> [Book] {
        ids.compactMap { library.book(id: $0) }.sorted { $0.title < $1.title }
    }

    var body: some View {
        Group {
            if books.isEmpty {
                MacEmptyState(title: EmptyCopy.chooseBook.title, message: EmptyCopy.chooseBook.message, systemImage: "book.closed")
            } else if books.count == 1, let book = books.first {
                single(book)
            } else {
                many(books)
            }
        }
        .onAppear(perform: load)
        // M12: al cambiar de libro se guarda lo que dejaste escrito, como en Finder o Fotos;
        // antes se perdía sin aviso.
        .onChange(of: ids) { old, _ in
            if draft != loaded { save(old) }
            load()
        }
        .onDisappear { if draft != loaded { save(ids) } }
        .errorAlert("No pude guardar los datos", message: $errorMessage, back: "Volver a la ficha")
    }

    // MARK: Un libro

    private func single(_ book: Book) -> some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    let shelf = model.shelfBook(id: book.id.uuidString)
                    CoverView(title: book.title, author: shelf?.author ?? "",
                              style: shelf?.cover ?? .generated(for: book.title), image: shelf?.coverImage)
                        .frame(width: Theme.Mac.inspectorCover.width, height: Theme.Mac.inspectorCover.height)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text(book.title).font(.rowTitle)
                        Text(shelf?.author ?? "").foregroundStyle(Theme.secondaryInk)
                        if let shelf, shelf.progress > 0 {
                            Text("\(shelf.progress.percentText) leído").foregroundStyle(Theme.secondaryInk).monospacedDigit()
                        }
                    }
                }
            }
            Section(BookSection.book.rawValue) {
                TextField("Título", text: $draft.title)
                TextField("Autores", text: $draft.authors, prompt: Text("Sepáralos con &"))
                TextField("Serie", text: $draft.series)
                TextField("Número en la serie", text: $draft.seriesIndex)
                if SeriesIndexInput(draft.seriesIndex).isInvalid {
                    Text(SeriesIndexInput.hint).font(.footnote).foregroundStyle(Theme.secondaryInk)
                }
            }
            Section(BookSection.edition.rawValue) {
                TextField("Editorial", text: $draft.publisher)
                TextField("Publicado", text: $draft.published, prompt: Text(BookFields.publishedPrompt))
                TextField("ISBN", text: $draft.isbn)
                LanguagePicker(code: $draft.language)
            }
            Section(BookSection.reading.rawValue) {
                StatusPicker(status: $draft.status)
                LabeledContent("Valoración") { RatingPicker(rating: $draft.rating) }
                TextField("Etiquetas", text: $draft.tags, prompt: Text("Sepáralas con comas"))
            }
            Section(BookSection.summary.rawValue) {
                // Con la letra y el fondo del resto de la ficha, no un recuadro blanco aparte.
                TextEditor(text: $draft.summary)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: Theme.Mac.summary)
            }
            buttons(count: 1)
        }
        .formStyle(.grouped)
        .formScreen()
    }

    // MARK: Varios libros

    private func many(_ books: [Book]) -> some View {
        Form {
            Section {
                Text(books.count.counted("libro elegido", "libros elegidos")).font(.rowTitle)
                Text("Lo que escribas se aplica a todos. Lo que dejes en blanco no cambia.")
                    .foregroundStyle(Theme.secondaryInk)
            }
            Section(BookSection.book.rawValue) {
                TextField("Autores", text: $draft.authors, prompt: Text(placeholder(BulkEdit.common(books) { BookFields.authorsText($0.authors) })))
                TextField("Serie", text: $draft.series, prompt: Text(placeholder(BulkEdit.common(books) { $0.series ?? "" })))
            }
            Section(BookSection.edition.rawValue) {
                TextField("Editorial", text: $draft.publisher, prompt: Text(placeholder(BulkEdit.common(books) { $0.publisher ?? "" })))
                LanguagePicker(code: $draft.language, none: BulkEdit.common(books) { $0.language ?? "" }
                    .map { $0.isEmpty ? "Sin cambiar" : "Sin cambiar (\(BookFields.languageName($0)))" } ?? "Sin cambiar (\(BookFields.mixed.lowercased()))")
            }
            Section(BookSection.reading.rawValue) {
                StatusPicker(status: $draft.status, keeps: "Sin cambiar")
                TextField("Agregar etiquetas", text: $draft.tags, prompt: Text("Sepáralas con comas"))
                TextField("Quitar etiquetas", text: $draft.removeTags,
                          prompt: Text(BookFields.tagsText(BulkEdit.sharedTags(books)).nonEmpty ?? "Sepáralas con comas"))
            }
            buttons(count: books.count)
        }
        .formStyle(.grouped)
        .formScreen()
    }

    private func buttons(count: Int) -> some View {
        Group {
            Section {
                if finding {
                    LoadingLine(text: "Buscando datos en internet…")
                } else {
                    Button {
                        let targets = ids
                        finding = true
                        Task {
                            for id in targets { _ = await library.identify(id) }
                            finding = false
                        }
                    } label: {
                        Label(LibraryAction.findData(count: count), systemImage: LibraryAction.findData.symbol)
                    }
                    .help("En Open Library (y Google Books, si pusiste su clave)")
                }
            }
            Section {
                HStack {
                    Button("Deshacer cambios") { draft = loaded }
                        .disabled(draft == loaded)
                    Spacer()
                    Button(count == 1 ? "Guardar cambios" : "Guardar en \(count.counted("libro", "libros"))") { save(ids) }
                        .keyboardShortcut("s")
                        .macMainAction()
                        .disabled(draft == loaded || (count == 1 && SeriesIndexInput(draft.seriesIndex).isInvalid))
                }
            }
        }
    }

    private func placeholder(_ common: String?) -> String {
        guard let common else { return BookFields.mixed }
        return common.isEmpty ? "—" : common
    }

    // MARK: Guardar

    private func load() {
        if books.count == 1, let book = books.first {
            draft = Draft(book)
        } else {
            draft = Draft()
            draft.status = nil
        }
        loaded = draft
    }

    /// Guarda en los libros de `targets`: los elegidos ahora, o los de antes si cambiaste de libro.
    /// Un número de tomo que no sirve no se guarda (se queda el que había).
    private func save(_ targets: Set<UUID>) {
        var failed: [String] = []
        let books = books(targets)
        if books.count == 1, let book = books.first {
            do { _ = try library.update(draft.applied(to: book)) } catch { failed.append(error.localizedDescription) }
        } else {
            let edit = draft.bulk
            for book in books where !edit.isEmpty {
                do { _ = try library.update(edit.apply(to: book)) } catch { failed.append("«\(book.title)»: \(error.localizedDescription)") }
            }
        }
        errorMessage = failed.isEmpty ? nil : failed.joined(separator: "\n")
        load()
    }
}

/// Lo que escribes en la ficha, como texto, antes de guardarlo en el libro.
private struct Draft: Equatable {
    var title = ""
    var authors = ""
    var series = ""
    var seriesIndex = ""
    var tags = ""
    var removeTags = ""
    var language = ""
    var publisher = ""
    var published = ""
    var isbn = ""
    var status: ReadingStatus? = .toRead
    var rating: Double?
    var summary = ""

    init() {}

    init(_ book: Book) {
        title = book.title
        authors = BookFields.authorsText(book.authors)
        series = book.series ?? ""
        seriesIndex = book.seriesIndex.flatMap(ShelfBook.number) ?? ""
        tags = BookFields.tagsText(book.tags)
        language = book.language ?? ""
        publisher = book.publisher ?? ""
        published = book.published ?? ""
        isbn = book.identifiers["isbn"] ?? ""
        status = book.readingStatus
        rating = (book.rating ?? 0).safeInt.map { min(5, max(0, $0)) }.flatMap { $0 == 0 ? nil : Double($0) }
        summary = book.summary ?? ""
    }

    func applied(to book: Book) -> Book {
        var book = book
        book.title = title.trimmingCharacters(in: .whitespaces).nonEmpty ?? book.title
        book.authors = BookFields.authors(authors)
        book.series = series.trimmingCharacters(in: .whitespaces).nonEmpty
        book.seriesIndex = book.series == nil ? nil : SeriesIndexInput(seriesIndex).value(keeping: book.seriesIndex)
        book.tags = BookFields.tags(tags)
        book.language = language.trimmingCharacters(in: .whitespaces).nonEmpty
        book.publisher = publisher.trimmingCharacters(in: .whitespaces).nonEmpty
        book.published = published.trimmingCharacters(in: .whitespaces).nonEmpty
        book.identifiers["isbn"] = BookFields.isbn(isbn)
        book.readingStatus = status ?? book.readingStatus
        book.rating = rating
        book.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return book
    }

    /// Con varios libros: solo lo que escribiste.
    var bulk: BulkEdit {
        BulkEdit(authors: BookFields.authors(authors).nonEmpty,
                 series: series.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 language: language.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 publisher: publisher.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 readingStatus: status,
                 addTags: BookFields.tags(tags),
                 removeTags: BookFields.tags(removeTags))
    }
}

/// «» se vuelve nil: para unir solo los datos que sí hay.
extension Collection {
    var nonEmpty: Self? { isEmpty ? nil : self }
}
#endif
