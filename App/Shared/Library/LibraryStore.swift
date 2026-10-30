import CryptoKit
import Foundation
import LectoraCore
import UniformTypeIdentifiers

/// La biblioteca: una carpeta con la misma forma que una de Calibre
/// (`Autor/Título (id)/archivo + cover.jpg + metadata.opf`) y un catálogo en el
/// registro de cambios de LectoraCore (`.lectora/registro/`). Si mañana quieres
/// volver a Calibre, abres la carpeta en Calibre y restauras la base de datos.
@MainActor
final class LibraryStore: ObservableObject {
    enum ImportOutcome {
        case added(Book)
        case duplicate(Book)
    }

    enum LibraryError: LocalizedError {
        case bookNotFound
        case folderTaken
        case coverUnavailable
        var errorDescription: String? {
            switch self {
            case .bookNotFound: "No encontré ese libro en la biblioteca."
            case .folderTaken: "Ya hay otro libro con ese título y autor en la carpeta."
            case .coverUnavailable: "No pude bajar esa portada. Prueba con otra."
            }
        }
    }

    static let shared = LibraryStore()

    static let importableTypes: [UTType] = [
        UTType(filenameExtension: "epub"),
        .pdf,
        UTType(filenameExtension: "mobi"),
        UTType(filenameExtension: "azw3"),
        UTType(filenameExtension: "fb2"),
        UTType(filenameExtension: "cbz"),
    ].compactMap { $0 }

    @Published private(set) var books: [Book] = []
    /// «Por revisar»: libros con datos dudosos y sus candidatos de internet.
    @Published private(set) var reviews: [UUID: [MetadataCandidate]] = [:]
    /// Libros que se están buscando en internet ahora mismo.
    @Published private(set) var identifying: Set<UUID> = []
    /// Libros que no se pudieron buscar en internet (sin conexión); se reintentan.
    @Published private(set) var pendingLookup: Set<UUID> = []
    /// Lo que se completó solo desde internet, para revisarlo y deshacerlo.
    @Published private(set) var filled: [UUID: FilledRecord] = [:]
    /// Reglas de autores y etiquetas (en la carpeta: viajan con la biblioteca).
    @Published private(set) var rules = MetadataRules()
    /// Avance de una importación en curso.
    @Published private(set) var progress: (done: Int, total: Int)?

    let root: URL
    private let log: ChangeLog
    private let clock: HybridLogicalClock
    private var state = LibraryState()
    private lazy var extractor = MetadataExtractor()
    /// Importaciones en fila: una termina antes de que empiece la siguiente.
    private var lastImport: Task<[Result<ImportOutcome, Error>], Never>?

    init(root: URL = LibraryStore.defaultRoot) {
        self.root = root
        let device = AnnotationStore.deviceID
        log = ChangeLog(directory: root.appendingPathComponent(".lectora/registro", isDirectory: true), deviceID: device)
        clock = HybridLogicalClock(node: device)
        reload()
        loadReviews()
    }

    /// «En mi iPhone › Lectora › Biblioteca Lectora» en la app Archivos.
    nonisolated static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Biblioteca Lectora", isDirectory: true)
    }

    func reload() {
        var fresh = LibraryState()
        if let result = try? log.readAll() { fresh.apply(result.changes) }
        if let latest = fresh.latest { clock.receive(latest) }
        state = fresh
        books = fresh.books()
    }

    func book(id: UUID) -> Book? { books.first { $0.id == id } }

    func fileURL(for book: Book) -> URL? {
        book.filePath.map { root.appendingPathComponent($0) }
    }

    func coverURL(for book: Book) -> URL? {
        guard let folder = book.folderPath else { return nil }
        let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.coverFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: Importar

    @discardableResult
    func importFiles(_ urls: [URL]) async -> [Result<ImportOutcome, Error>] {
        let previous = lastImport
        let task = Task { @MainActor in
            _ = await previous?.value
            return await self.runImport(urls)
        }
        lastImport = task
        return await task.value
    }

    private func runImport(_ urls: [URL]) async -> [Result<ImportOutcome, Error>] {
        progress = (0, urls.count)
        defer { progress = nil }
        var results: [Result<ImportOutcome, Error>] = []
        var added: [Book] = []
        for (index, url) in urls.enumerated() {
            do {
                let outcome = try await importFile(url)
                if case .added(let book) = outcome { added.append(book) }
                results.append(.success(outcome))
            } catch {
                results.append(.failure(error))
            }
            progress = (index + 1, urls.count)
        }
        // Después de importar, se buscan en internet sin detener la fila.
        Task { [added] in
            for book in added { await self.identify(book.id) }
        }
        return results
    }

    /// Lee el archivo, evita duplicados, limpia los datos y lo guarda ordenado.
    func importFile(_ source: URL) async throws -> ImportOutcome {
        // Copia y huella fuera del hilo de la interfaz: un PDF de 300 MB no congela la app.
        let (staging, hash) = try await Task.detached(priority: .userInitiated) {
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(source.pathExtension.lowercased())
            try FileManager.default.copyItem(at: source, to: staging)
            return (staging, try LibraryStore.sha256(of: staging))
        }.value
        defer { try? FileManager.default.removeItem(at: staging) }

        if let existing = books.first(where: { $0.fileHash == hash }) { return .duplicate(existing) }

        let extracted = (try? await extractor.extract(from: staging)) ?? ExtractedMetadata()
        var book = MetadataCleaner.clean(Book(
            title: extracted.title ?? "",
            authors: extracted.authors,
            series: extracted.series,
            seriesIndex: extracted.seriesIndex,
            tags: extracted.tags,
            language: extracted.language,
            identifiers: extracted.isbn.map { ["isbn": $0] } ?? [:],
            publisher: extracted.publisher,
            published: extracted.published,
            summary: extracted.summary
        ), fileName: source.lastPathComponent)
        book = rules.apply(to: book)
        // Mismo ISBN y mismo formato: es el mismo libro. (Un PDF y un EPUB de la
        // misma edición sí entran; luego se podrán unir como formatos de un libro.)
        let format = source.pathExtension.lowercased()
        if let isbn = book.identifiers["isbn"].flatMap(ISBN.normalized), let existing = books.first(where: {
            $0.identifiers["isbn"].flatMap(ISBN.normalized) == isbn && ($0.filePath as NSString?)?.pathExtension.lowercased() == format
        }) {
            return .duplicate(existing)
        }

        // Número de Calibre libre, también en disco (otro dispositivo pudo usarlo).
        var calibreID = (books.compactMap(\.calibreID).max() ?? 0) + 1
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(
            CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)).path) {
            calibreID += 1
        }
        book.calibreID = calibreID
        book.fileHash = hash
        book.addedAt = Date()

        let folder = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
        let fileName = CalibreLayout.fileName(title: book.title, authors: book.authors, fileExtension: format)
        let folderURL = root.appendingPathComponent(folder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: staging, to: folderURL.appendingPathComponent(fileName))
            book.filePath = "\(folder)/\(fileName)"

            var hasCover = false
            if let cover = extracted.cover.flatMap({ CoverImaging.jpeg(from: $0) }) {
                try cover.write(to: folderURL.appendingPathComponent(CalibreLayout.coverFileName), options: .atomic)
                hasCover = true
            }
            try writeOPF(book, hasCover: hasCover)
            try record(book)
            return .added(book)
        } catch {
            // Nada a medias: si algo falla, la carpeta del libro no se queda.
            try? FileManager.default.removeItem(at: folderURL)
            removeIfEmpty(folderURL.deletingLastPathComponent())
            throw error
        }
    }

    // MARK: Editar

    /// Guarda la edición manual. Si cambian el título o el primer autor, la
    /// carpeta y el archivo se renombran como lo haría Calibre.
    @discardableResult
    func update(_ edited: Book, cover newCover: Data? = nil) throws -> Book {
        guard let original = book(id: edited.id) else { throw LibraryError.bookNotFound }
        var book = MetadataCleaner.clean(edited, manual: true)

        if let oldPath = original.filePath, let calibreID = book.calibreID,
           original.title != book.title || original.authors.first != book.authors.first {
            let oldFolder = root.appendingPathComponent((oldPath as NSString).deletingLastPathComponent, isDirectory: true)
            let newFolderPath = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
            let newFolder = root.appendingPathComponent(newFolderPath, isDirectory: true)
            let newName = CalibreLayout.fileName(title: book.title, authors: book.authors,
                                                 fileExtension: (oldPath as NSString).pathExtension)
            let movesFolder = newFolder.standardizedFileURL != oldFolder.standardizedFileURL
            if movesFolder {
                guard !FileManager.default.fileExists(atPath: newFolder.path) else { throw LibraryError.folderTaken }
                try FileManager.default.createDirectory(at: newFolder.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: oldFolder, to: newFolder)
            }
            let oldFile = newFolder.appendingPathComponent((oldPath as NSString).lastPathComponent)
            let newFile = newFolder.appendingPathComponent(newName)
            do {
                if oldFile.lastPathComponent != newName {
                    try FileManager.default.moveItem(at: oldFile, to: newFile)
                }
            } catch {
                // Deshacer el cambio de carpeta: el libro sigue donde estaba.
                if movesFolder { try? FileManager.default.moveItem(at: newFolder, to: oldFolder) }
                throw error
            }
            if movesFolder {
                removeIfEmpty(oldFolder.deletingLastPathComponent())
                CoverImaging.forget(oldFolder.appendingPathComponent(CalibreLayout.coverFileName))
            }
            book.filePath = "\(newFolderPath)/\(newName)"
        }

        if let newCover, let jpeg = CoverImaging.jpeg(from: newCover), let folder = book.folderPath {
            let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.coverFileName)
            try jpeg.write(to: url, options: .atomic)
            CoverImaging.forget(url)
        }
        try writeOPF(book, hasCover: coverURL(for: book) != nil)
        try record(book)
        return book
    }

    // MARK: Buscar en internet

    /// Búsqueda en Open Library (y en Google Books si diste una clave en Ajustes).
    private var service: MetadataService {
        MetadataService(googleKey: UserDefaults.standard.string(forKey: MetadataKeys.googleKey))
    }

    /// Busca el libro en internet. Si es claramente el mismo libro, completa lo
    /// que falta (y la portada); si hay dudas, lo deja en «Por revisar». Sin
    /// internet no lo manda a revisar: queda pendiente y se vuelve a intentar.
    /// Con `askAlways` (desde la ficha) siempre deja los candidatos para elegir.
    @discardableResult
    func identify(_ bookID: UUID, askAlways: Bool = false) async -> MetadataService.Decision? {
        guard let book = book(id: bookID), !identifying.contains(bookID) else { return nil }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }

        let result = await service.lookup(book)
        if result.decision == .unreachable {
            setPending(bookID, true)
            return .unreachable
        }
        setPending(bookID, false)
        if result.decision == .apply, !askAlways, let best = result.candidates.first {
            var cover: Data?
            if coverURL(for: book) == nil { cover = await service.cover(for: best, language: book.language, title: book.title) }
            // Pudo cambiar mientras se buscaba (lo editaste): se completa lo más reciente.
            let current = self.book(id: bookID) ?? book
            let completed = rules.apply(to: MetadataMatcher.fillMissing(current, from: best))
            if (try? update(completed, cover: cover)) != nil {
                recordFilled(before: current, after: completed, addedCover: cover != nil)
            }
            setReview(bookID, candidates: nil)
        } else {
            setReview(bookID, candidates: result.candidates)
        }
        return result.decision
    }

    /// «Buscar con otros datos»: otro título, autor o ISBN. Los candidatos
    /// reemplazan a los de «Por revisar» de ese libro.
    @discardableResult
    func search(title: String, author: String?, isbn: String?, for bookID: UUID) async -> MetadataService.Decision? {
        guard let book = book(id: bookID), !identifying.contains(bookID) else { return nil }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }
        let result = await service.search(title: title, author: author, isbn: isbn, for: book)
        if result.decision != .unreachable { setReview(bookID, candidates: result.candidates) }
        return result.decision
    }

    /// Completa un candidato con su sinopsis (para la vista previa).
    func details(for candidate: MetadataCandidate, bookID: UUID) async -> MetadataCandidate {
        guard let book = book(id: bookID) else { return candidate }
        let detailed = await service.withSummary(candidate, for: book)
        if detailed.summary != candidate.summary, var list = reviews[bookID],
           let index = list.firstIndex(where: { $0.id == candidate.id }) {
            list[index] = detailed
            setReview(bookID, candidates: list)
        }
        return detailed
    }

    /// Qué portada usar al aplicar un candidato.
    enum CoverPick: Hashable {
        /// La que tiene el libro.
        case keep
        /// La mejor que encuentre Lectora.
        case automatic
        /// La que elegiste en la cuadrícula.
        case url(URL)
    }

    /// Elegiste un candidato: sus datos (y la portada que elijas) reemplazan a los del libro.
    func apply(_ candidate: MetadataCandidate, to bookID: UUID, cover pick: CoverPick = .automatic) async throws {
        guard let book = book(id: bookID) else { throw LibraryError.bookNotFound }
        let detailed = await service.withSummary(candidate, for: book)
        let cover: Data?
        switch pick {
        case .keep: cover = nil
        case .automatic: cover = await service.cover(for: detailed, language: book.language)
        case .url(let url): cover = await service.coverData(at: url)
        }
        let current = self.book(id: bookID) ?? book
        try update(rules.apply(to: MetadataMatcher.replace(current, with: detailed)), cover: cover)
        setReview(bookID, candidates: nil)
        forgetFilled(bookID)
    }

    // MARK: Portadas para elegir

    /// Portadas de internet para un candidato (las de sus ediciones primero).
    func coverOptions(for candidate: MetadataCandidate, bookID: UUID) async -> [URL] {
        let book = book(id: bookID)
        return await service.coverOptions(for: candidate, language: book?.language, title: candidate.title, limit: 8)
    }

    /// Portadas de internet para un libro: las de su obra si ya se conoce
    /// (openlibrary: en el catálogo), si no, las de lo que encuentre la búsqueda.
    func coverOptions(for bookID: UUID) async -> [URL] {
        guard let book = book(id: bookID) else { return [] }
        var candidates: [MetadataCandidate] = []
        if let work = book.identifiers["openlibrary"] {
            candidates = [MetadataCandidate(id: "ol:/works/\(work)", source: .openLibrary, title: book.title,
                                            workKey: "/works/\(work)")]
        } else {
            candidates = Array(await service.lookup(book).candidates.prefix(3))
        }
        var urls: [URL] = []
        for candidate in candidates {
            let options = await service.coverOptions(for: candidate, language: book.language, title: book.title, limit: 8)
            for url in options where !urls.contains(url) { urls.append(url) }
        }
        return Array(urls.prefix(12))
    }

    /// Cambia la portada por la elegida en la cuadrícula.
    func setCover(_ url: URL, for bookID: UUID) async throws {
        guard let data = await service.coverData(at: url) else { throw LibraryError.coverUnavailable }
        guard let book = book(id: bookID) else { throw LibraryError.bookNotFound }
        try update(book, cover: data)
    }

    // MARK: Reglas

    func saveRules(_ new: MetadataRules) {
        rules = new
        save(new, to: rulesURL)
    }

    /// Aplica las reglas a toda la biblioteca. Devuelve cuántos libros cambiaron.
    @discardableResult
    func applyRulesToLibrary() -> Int {
        var changed = 0
        for book in books {
            let mapped = rules.apply(to: book)
            if mapped != book, (try? update(mapped)) != nil { changed += 1 }
        }
        return changed
    }

    // MARK: Lo que se completó solo

    private func recordFilled(before: Book, after: Book, addedCover: Bool) {
        var changes = FilledField.allCases.compactMap { field -> FilledChange? in
            guard field != .cover else { return nil }
            let old = field.value(in: before), new = field.value(in: after)
            return old == new ? nil : FilledChange(field: field, old: old, new: new)
        }
        if addedCover { changes.append(FilledChange(field: .cover, old: nil, new: "Nueva")) }
        guard !changes.isEmpty else { return }
        filled[before.id] = FilledRecord(date: Date(), changes: changes)
        save(filled, to: filledURL)
    }

    /// Deshace un dato que se completó solo. Si lo cambiaste después, se respeta lo tuyo.
    func undoFilled(_ field: FilledField, for bookID: UUID) throws {
        guard var record = filled[bookID], let change = record.changes.first(where: { $0.field == field }),
              var book = book(id: bookID) else { return }
        if field == .cover {
            if let url = coverURL(for: book) {
                try FileManager.default.removeItem(at: url)
                CoverImaging.forget(url)
            }
            try update(book)
        } else if field.value(in: book) == change.new {
            field.restore(change.old, in: &book)
            try update(book)
        }
        record.changes.removeAll { $0.field == field }
        filled[bookID] = record.changes.isEmpty ? nil : record
        save(filled, to: filledURL)
    }

    func undoAllFilled(for bookID: UUID) throws {
        for change in filled[bookID]?.changes ?? [] { try undoFilled(change.field, for: bookID) }
    }

    /// «Está bien»: se queda así y sale de la lista.
    func forgetFilled(_ bookID: UUID) {
        guard filled[bookID] != nil else { return }
        filled[bookID] = nil
        save(filled, to: filledURL)
    }

    func forgetAllFilled() {
        filled = [:]
        save(filled, to: filledURL)
    }

    /// «Mantener mis datos»: sale de la bandeja sin cambiar nada.
    func dismissReview(_ bookID: UUID) {
        setReview(bookID, candidates: nil)
    }

    /// Vuelve a buscar los libros que se quedaron sin buscar por falta de internet.
    func retryPendingLookups() async {
        for id in pendingLookup where book(id: id) != nil {
            if await identify(id) == .unreachable { break }
        }
    }

    private var reviewsURL: URL {
        root.appendingPathComponent(".lectora/por-revisar.json")
    }

    private var filledURL: URL {
        root.appendingPathComponent(".lectora/completados.json")
    }

    private var rulesURL: URL {
        root.appendingPathComponent(".lectora/reglas.json")
    }

    private var pendingURL: URL {
        root.appendingPathComponent(".lectora/por-buscar.json")
    }

    private func setReview(_ bookID: UUID, candidates: [MetadataCandidate]?) {
        reviews[bookID] = candidates
        save(reviews, to: reviewsURL)
    }

    private func setPending(_ bookID: UUID, _ pending: Bool) {
        guard pendingLookup.contains(bookID) != pending else { return }
        if pending { pendingLookup.insert(bookID) } else { pendingLookup.remove(bookID) }
        save(pendingLookup, to: pendingURL)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func loadReviews() {
        if let data = try? Data(contentsOf: reviewsURL),
           let saved = try? JSONDecoder().decode([UUID: [MetadataCandidate]].self, from: data) {
            reviews = saved.filter { book(id: $0.key) != nil }
        }
        if let data = try? Data(contentsOf: pendingURL), let saved = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            pendingLookup = saved.filter { book(id: $0) != nil }
        }
        if let data = try? Data(contentsOf: filledURL),
           let saved = try? JSONDecoder().decode([UUID: FilledRecord].self, from: data) {
            filled = saved.filter { book(id: $0.key) != nil }
        }
        if let data = try? Data(contentsOf: rulesURL), let saved = try? JSONDecoder().decode(MetadataRules.self, from: data) {
            rules = saved
        }
    }

    // MARK: Posición de lectura

    struct ReadingPosition {
        var cfi: String?
        var fraction: Double
        /// Las primeras palabras de la página, para «Donde lo dejaste».
        var excerpt: String?
        var updatedAt: Date? = nil
    }

    func position(for bookID: UUID) -> ReadingPosition? {
        guard let fields = state.fields(of: .progress, id: bookID) else { return nil }
        return ReadingPosition(
            cfi: fields["cfi"]?.stringValue,
            fraction: fields["fraction"]?.doubleValue ?? 0,
            excerpt: fields["excerpt"]?.stringValue,
            updatedAt: fields["updated_at"]?.doubleValue.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Guarda dónde vas (en el mismo registro que se sincroniza).
    func savePosition(_ position: ReadingPosition, for bookID: UUID) {
        let values: [(String, JSONValue)] = [
            ("cfi", position.cfi.map(JSONValue.string) ?? .null),
            ("fraction", .number(position.fraction)),
            ("excerpt", position.excerpt.map(JSONValue.string) ?? .null),
            ("updated_at", .number(Date().timeIntervalSince1970)),
        ]
        let changes = values.map { Change(hlc: clock.tick(), entity: .progress, entityID: bookID, field: $0.0, value: $0.1) }
        try? log.append(changes)
        state.apply(changes)
        objectWillChange.send()
    }

    // MARK: Interno

    private func writeOPF(_ book: Book, hasCover: Bool) throws {
        guard let folder = book.folderPath else { return }
        let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.opfFileName)
        try Data(CalibreOPF.write(book, hasCover: hasCover).utf8).write(to: url, options: .atomic)
    }

    private func record(_ book: Book) throws {
        let changes = book.changes(clock: clock)
        try log.append(changes)
        state.apply(changes)
        books = state.books()
    }

    private func removeIfEmpty(_ folder: URL) {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? ["?"]
        if contents.filter({ $0 != ".DS_Store" }).isEmpty { try? FileManager.default.removeItem(at: folder) }
    }

    nonisolated static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
