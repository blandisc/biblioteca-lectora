#if os(macOS)
import LectoraCore
import SwiftUI
import UniformTypeIdentifiers

/// La ficha a la derecha de la tabla (MG-1). Con un libro, todos sus datos; con varios,
/// lo que cambies se aplica a todos (lo que dejes en blanco no se toca).
struct MacBookInspector: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var library: LibraryStore
    let ids: Set<UUID>

    @State private var draft = Draft()
    @State private var loaded = Draft()
    /// El libro como estaba al abrir la ficha: al guardar solo se escribe lo que cambiaste
    /// desde entonces, encima del libro de ahora (auditoría 1).
    @State private var loadedBook: Book?
    @State private var errorMessage: String?
    /// Mientras se buscan los datos en internet: la ficha lo dice, no corre en silencio (C8).
    @State private var finding = false
    /// Cambiar la portada (MX-B): una imagen de tu Mac o una de internet, como en el iPhone.
    @State private var choosingCoverFile = false
    @State private var choosingInternetCover = false
    /// Una nota del libro abierta desde la ficha.
    @State private var openNote: NoteRef?

    private var books: [Book] { books(ids) }

    private func books(_ ids: Set<UUID>) -> [Book] {
        let found = ids.compactMap { library.book(id: $0) }.sorted { $0.title < $1.title }
        #if DEBUG
        // Capturas: `-screenshot.long` enseña el libro elegido con datos larguísimos, solo en
        // pantalla (no se guarda), para revisar que la ficha corte con «…» (UX-3b).
        if UserDefaults.standard.bool(forKey: "screenshot.long") {
            return found.map { book in
                var long = book
                long.title = "Historia verdadera de la conquista de la Nueva España escrita por uno de sus conquistadores"
                long.authors = ["Bernal Díaz del Castillo Fernández de Córdoba y Grijalva", "Juan Ginés de Sepúlveda y Montenegro"]
                long.series = "Crónicas de Indias y relaciones del siglo dieciséis"
                long.publisher = "Imprenta del Reino, por Francisco Martínez Abad y herederos"
                long.tags = ["Crónicas", "Historia de México", "Siglo XVI", "Conquista"]
                return long
            }
        }
        #endif
        return found
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
        let shelf = model.shelfBook(id: book.id.uuidString)
        return Form {
            Section {
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    CoverView(title: book.title, author: shelf?.author ?? "",
                              style: shelf?.cover ?? .generated(for: book.title), image: shelf?.coverImage)
                        .frame(width: Theme.Mac.inspectorCover.width, height: Theme.Mac.inspectorCover.height)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        // Un título largo se corta con «…» en vez de empujar la ficha (regla 9).
                        Text(book.title).font(.rowTitle).foregroundStyle(Theme.ink)
                            .lineLimit(Theme.Size.labelLines).truncationMode(.tail)
                        Text(shelf?.author ?? "").foregroundStyle(Theme.secondaryInk)
                            .lineLimit(1).truncationMode(.tail)
                        if let shelf, shelf.progress > 0 {
                            Text("\(shelf.progress.percentText) leído").foregroundStyle(Theme.secondaryInk).monospacedDigit()
                        }
                    }
                }
                // Leer, como el doble clic en la tabla, y cambiar la portada.
                HStack(spacing: Theme.Space.s) {
                    if let shelf {
                        Button { model.open(shelf) } label: { Label(shelf.state.openAction, systemImage: shelf.state.symbol) }
                            .disabled(shelf.file == nil)
                            .help("Abrir el libro en su ventana")
                    }
                    Menu("Portada") {
                        Button("Elegir una imagen…") { choosingCoverFile = true }
                        Button("Buscar portada en internet…") { choosingInternetCover = true }
                    }
                    .help("Cambiar la portada")
                }
                // Acciones en tinta, no en verde (regla 1), en claro y en oscuro.
                .tint(Theme.ink)
            }
            annotations(of: book)
            Section(BookSection.book.rawValue) {
                TextField("Título", text: $draft.title).oneLine()
                TextField("Autores", text: $draft.authors, prompt: Text("Sepáralos con &")).oneLine()
                TextField("Serie", text: $draft.series).oneLine()
                TextField("Número en la serie", text: $draft.seriesIndex).oneLine()
                if SeriesIndexInput(draft.seriesIndex).isInvalid {
                    Text(SeriesIndexInput.hint).font(.footnote).foregroundStyle(Theme.secondaryInk)
                }
            }
            Section(BookSection.edition.rawValue) {
                TextField("Editorial", text: $draft.publisher).oneLine()
                TextField("Publicado", text: $draft.published, prompt: Text(BookFields.publishedPrompt)).oneLine()
                TextField("ISBN", text: $draft.isbn).oneLine()
                LanguagePicker(code: $draft.language)
            }
            Section(BookSection.reading.rawValue) {
                StatusPicker(status: $draft.status)
                LabeledContent("Valoración") { RatingPicker(rating: $draft.rating) }
                TextField("Etiquetas", text: $draft.tags, prompt: Text("Sepáralas con comas")).oneLine()
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
        .formScreen()
        #if DEBUG
        // Capturas: con un libro elegido (`-screenshot.pick Rayuela`), `-screenshot.inspector note`
        // abre su primera nota y `cover`, «Buscar portada en internet…», como el clic.
        .task(id: book.id) {
            switch UserDefaults.standard.string(forKey: "screenshot.inspector") {
            case "note": openNote = model.notes.notes(linking: book.title).first.map { NoteRef(fileName: $0.fileName) }
            case "cover": choosingInternetCover = true
            default: break
            }
        }
        #endif
        .fileImporter(isPresented: $choosingCoverFile, allowedContentTypes: [.image]) { result in
            setCover(result, for: book)
        }
        .sheet(isPresented: $choosingInternetCover) {
            CoverPickerSheet(bookID: book.id)
                .environmentObject(model)
                .frame(width: Theme.Mac.sheet.width, height: Theme.Mac.sheet.height)
        }
        .sheet(item: $openNote) { ref in
            NavigationStack {
                NoteScreen(ref: ref)
                    // En una hoja no hay barra arriba que deje su aire (en la ventana sí): el que le toca.
                    .contentMargins(.top, Theme.Space.screenTopInSheet, for: .scrollContent)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Volver a la ficha") { openNote = nil }
                        }
                    }
            }
            .environmentObject(model)
            .frame(width: Theme.Mac.sheet.width, height: Theme.Mac.sheet.height)
        }
    }

    /// Los subrayados y las notas del libro, los primeros (`Lists.inspectorItems`): cada uno
    /// se abre con un clic, el subrayado en su página y la nota en su hoja.
    @ViewBuilder
    private func annotations(of book: Book) -> some View {
        let highlights = model.annotations.annotations(forBook: book.id)
        let notes = model.notes.notes(linking: book.title)
        if !highlights.isEmpty {
            Section(highlights.count.counted("subrayado", "subrayados")) {
                ForEach(highlights.prefix(Theme.Lists.inspectorItems)) { highlight in
                    Button { model.openPassage(annotationID: highlight.id) } label: {
                        Text(highlight.quote)
                            .font(.quote)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(Theme.Size.labelLines)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir el libro en este subrayado")
                }
                if highlights.count > Theme.Lists.inspectorItems {
                    Text("y \(highlights.count - Theme.Lists.inspectorItems) más en el libro")
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        if !notes.isEmpty {
            Section(notes.count.counted("nota", "notas")) {
                ForEach(notes.prefix(Theme.Lists.inspectorItems)) { note in
                    Button { openNote = NoteRef(fileName: note.fileName) } label: {
                        Label(note.title, systemImage: "note.text")
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir la nota")
                }
                if notes.count > Theme.Lists.inspectorItems {
                    Text("y \(notes.count - Theme.Lists.inspectorItems) más en el Cuaderno")
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }

    /// La portada elegida de un archivo: se guarda en el libro como en el iPhone (`update(_:cover:)`).
    /// Lo que dejaste escrito en la ficha se queda como estaba.
    private func setCover(_ result: Result<URL, Error>, for book: Book) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let current = library.book(id: book.id) else { return }
            _ = try library.update(current, cover: data)
        } catch {
            errorMessage = error.localizedDescription
        }
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
                TextField("Autores", text: $draft.authors, prompt: Text(placeholder(BulkEdit.common(books) { BookFields.authorsText($0.authors) }))).oneLine()
                TextField("Serie", text: $draft.series, prompt: Text(placeholder(BulkEdit.common(books) { $0.series ?? "" }))).oneLine()
            }
            Section(BookSection.edition.rawValue) {
                TextField("Editorial", text: $draft.publisher, prompt: Text(placeholder(BulkEdit.common(books) { $0.publisher ?? "" }))).oneLine()
                LanguagePicker(code: $draft.language, none: BulkEdit.common(books) { $0.language ?? "" }
                    .map { $0.isEmpty ? "Sin cambiar" : "Sin cambiar (\(BookFields.languageName($0)))" } ?? "Sin cambiar (\(BookFields.mixed.lowercased()))")
            }
            Section(BookSection.reading.rawValue) {
                StatusPicker(status: $draft.status, keeps: "Sin cambiar")
                TextField("Agregar etiquetas", text: $draft.tags, prompt: Text("Sepáralas con comas")).oneLine()
                TextField("Quitar etiquetas", text: $draft.removeTags,
                          prompt: Text(BookFields.tagsText(BulkEdit.sharedTags(books)).nonEmpty ?? "Sepáralas con comas")).oneLine()
            }
            buttons(count: books.count)
        }
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
            loadedBook = book
        } else {
            draft = Draft()
            draft.status = nil
            loadedBook = nil
        }
        loaded = draft
    }

    /// Guarda en los libros de `targets`: los elegidos ahora, o los de antes si cambiaste de libro.
    /// Un número de tomo que no sirve no se guarda (se queda el que había).
    private func save(_ targets: Set<UUID>) {
        var failed: [String] = []
        let books = books(targets)
        if books.count == 1, let current = books.first {
            // Lo que no tocaste (la valoración de 3.5, una sinopsis que llegó de internet) se queda
            // como está ahora; antes la ficha entera pisaba lo más nuevo.
            let base = loadedBook?.id == current.id ? loadedBook ?? current : current
            let edited = Book.applyingEdits(from: draft.applied(to: base), loaded: loaded.applied(to: base), onto: current)
            do { _ = try library.update(edited) } catch { failed.append(error.localizedDescription) }
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
