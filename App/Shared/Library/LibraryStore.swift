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
        var errorDescription: String? {
            switch self {
            case .bookNotFound: "No encontré ese libro en la biblioteca."
            case .folderTaken: "Ya hay otro libro con ese título y autor en la carpeta."
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
        for (index, url) in urls.enumerated() {
            do {
                results.append(.success(try await importFile(url)))
            } catch {
                results.append(.failure(error))
            }
            progress = (index + 1, urls.count)
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
        // Mismo ISBN y mismo formato: es el mismo libro. (Un PDF y un EPUB de la
        // misma edición sí entran; luego se podrán unir como formatos de un libro.)
        let format = source.pathExtension.lowercased()
        if let isbn = book.identifiers["isbn"], let existing = books.first(where: {
            $0.identifiers["isbn"] == isbn && ($0.filePath as NSString?)?.pathExtension.lowercased() == format
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
