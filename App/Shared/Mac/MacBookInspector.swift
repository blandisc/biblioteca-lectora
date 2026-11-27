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

    private var books: [Book] { ids.compactMap { library.book(id: $0) }.sorted { $0.title < $1.title } }

    var body: some View {
        Group {
            if books.isEmpty {
                ContentUnavailableView("Elige un libro", systemImage: "book.closed",
                                       description: Text("Con varios elegidos, lo que cambies aquí se aplica a todos."))
            } else if books.count == 1, let book = books.first {
                single(book)
            } else {
                many(books)
            }
        }
        .onAppear(perform: load)
        .onChange(of: ids) { _, _ in load() }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Volver a la ficha", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
                        Text(book.title).font(.headline)
                        Text(shelf?.author ?? "").foregroundStyle(.secondary)
                        if let shelf, shelf.progress > 0 {
                            Text("\(shelf.progress.percentText) leído").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            Section("Libro") {
                TextField("Título", text: $draft.title)
                TextField("Autores", text: $draft.authors, prompt: Text("Separados por comas"))
                TextField("Serie", text: $draft.series)
                TextField("Número en la serie", text: $draft.seriesIndex)
                TextField("Etiquetas", text: $draft.tags, prompt: Text("Separadas por comas"))
            }
            Section("Edición") {
                TextField("Idioma", text: $draft.language, prompt: Text("es, en, fr…"))
                TextField("Editorial", text: $draft.publisher)
                TextField("Publicado", text: $draft.published, prompt: Text("2016 o 2016-05-01"))
                TextField("ISBN", text: $draft.isbn)
            }
            Section("Tu lectura") {
                Picker("Estado", selection: $draft.status) {
                    ForEach(ReadingStatus.allCases, id: \.self) { Text(Self.name($0)).tag(Optional($0)) }
                }
                Picker("Valoración", selection: $draft.rating) {
                    Text("Sin valorar").tag(0)
                    ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0)).tag($0) }
                }
            }
            Section("Sinopsis") {
                // Con la letra y el fondo del resto de la ficha, no un recuadro blanco aparte.
                TextEditor(text: $draft.summary)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: Theme.Mac.summary)
            }
            buttons(count: 1)
        }
        .formStyle(.grouped)
    }

    // MARK: Varios libros

    private func many(_ books: [Book]) -> some View {
        Form {
            Section {
                Text(books.count.counted("libro elegido", "libros elegidos")).font(.headline)
                Text("Lo que escribas se aplica a todos. Lo que dejes en blanco no cambia.")
                    .foregroundStyle(.secondary)
            }
            Section("Libro") {
                TextField("Autores", text: $draft.authors, prompt: Text(placeholder(BulkEdit.common(books) { $0.authors.joined(separator: ", ") })))
                TextField("Serie", text: $draft.series, prompt: Text(placeholder(BulkEdit.common(books) { $0.series ?? "" })))
                TextField("Agregar etiquetas", text: $draft.tags, prompt: Text("Separadas por comas"))
                TextField("Quitar etiquetas", text: $draft.removeTags,
                          prompt: Text(BulkEdit.sharedTags(books).joined(separator: ", ").nonEmpty ?? "Separadas por comas"))
            }
            Section("Edición") {
                TextField("Idioma", text: $draft.language, prompt: Text(placeholder(BulkEdit.common(books) { $0.language ?? "" })))
                TextField("Editorial", text: $draft.publisher, prompt: Text(placeholder(BulkEdit.common(books) { $0.publisher ?? "" })))
            }
            Section("Tu lectura") {
                Picker("Estado", selection: $draft.status) {
                    Text("Sin cambiar").tag(ReadingStatus?.none)
                    ForEach(ReadingStatus.allCases, id: \.self) { Text(Self.name($0)).tag(Optional($0)) }
                }
            }
            buttons(count: books.count)
        }
        .formStyle(.grouped)
    }

    private func buttons(count: Int) -> some View {
        Group {
            Section {
                Button(count == 1 ? "Buscar portada y datos" : "Buscar portada y datos para los \(count)") {
                    let targets = ids
                    Task { for id in targets { _ = await library.identify(id) } }
                }
                .help("En Open Library (y Google Books, si pusiste su clave)")
            }
            Section {
                HStack {
                    Button("Deshacer cambios") { draft = loaded }
                        .disabled(draft == loaded)
                    Spacer()
                    Button(count == 1 ? "Guardar" : "Aplicar a los \(count)") { save() }
                        .keyboardShortcut("s")
                        .buttonStyle(.borderedProminent)
                        .disabled(draft == loaded)
                }
            }
        }
    }

    private func placeholder(_ common: String?) -> String {
        guard let common else { return "Varios" }
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

    private func save() {
        var failed: [String] = []
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

    static func name(_ status: ReadingStatus) -> String {
        switch status {
        case .toRead: "Por leer"
        case .reading: "Leyendo"
        case .finished: "Leído"
        case .abandoned: "Abandonado"
        }
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
    var rating = 0
    var summary = ""

    init() {}

    init(_ book: Book) {
        title = book.title
        authors = book.authors.joined(separator: ", ")
        series = book.series ?? ""
        seriesIndex = book.seriesIndex.map(ShelfBook.number) ?? ""
        tags = book.tags.joined(separator: ", ")
        language = book.language ?? ""
        publisher = book.publisher ?? ""
        published = book.published ?? ""
        isbn = book.identifiers["isbn"] ?? ""
        status = book.readingStatus
        rating = Int((book.rating ?? 0).rounded())
        summary = book.summary ?? ""
    }

    func applied(to book: Book) -> Book {
        var book = book
        book.title = title.trimmingCharacters(in: .whitespaces).nonEmpty ?? book.title
        book.authors = BulkEdit.list(authors)
        book.series = series.trimmingCharacters(in: .whitespaces).nonEmpty
        book.seriesIndex = book.series == nil ? nil : Double(seriesIndex.replacingOccurrences(of: ",", with: "."))
        book.tags = BulkEdit.list(tags)
        book.language = language.trimmingCharacters(in: .whitespaces).nonEmpty
        book.publisher = publisher.trimmingCharacters(in: .whitespaces).nonEmpty
        book.published = published.trimmingCharacters(in: .whitespaces).nonEmpty
        book.identifiers["isbn"] = isbn.filter { $0.isNumber || $0 == "X" }.nonEmpty
        book.readingStatus = status ?? book.readingStatus
        book.rating = rating == 0 ? nil : Double(rating)
        book.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return book
    }

    /// Con varios libros: solo lo que escribiste.
    var bulk: BulkEdit {
        BulkEdit(authors: BulkEdit.list(authors).nonEmpty,
                 series: series.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 language: language.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 publisher: publisher.trimmingCharacters(in: .whitespaces).nonEmpty.map { .some($0) },
                 readingStatus: status,
                 addTags: BulkEdit.list(tags),
                 removeTags: BulkEdit.list(removeTags))
    }
}

private extension Collection {
    var nonEmpty: Self? { isEmpty ? nil : self }
}
#endif
