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
        var errorDescription: String? { "No encontré ese libro en la biblioteca." }
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
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension.lowercased())
        try FileManager.default.copyItem(at: source, to: staging)
        defer { try? FileManager.default.removeItem(at: staging) }

        let hash = try Self.sha256(of: staging)
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
        if let isbn = book.identifiers["isbn"], let existing = books.first(where: { $0.identifiers["isbn"] == isbn }) {
            return .duplicate(existing)
        }
        book.calibreID = (books.compactMap(\.calibreID).max() ?? 0) + 1
        book.fileHash = hash
        book.addedAt = Date()

        let folder = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: book.calibreID!)
        let fileName = CalibreLayout.fileName(title: book.title, authors: book.authors, fileExtension: source.pathExtension)
        let folderURL = root.appendingPathComponent(folder, isDirectory: true)
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
    }

    // MARK: Editar

    /// Guarda la edición manual. Si cambian el título o el primer autor, la
    /// carpeta y el archivo se renombran como lo haría Calibre.
    @discardableResult
    func update(_ edited: Book, cover newCover: Data? = nil) throws -> Book {
        guard let original = book(id: edited.id) else { throw LibraryError.bookNotFound }
        var book = MetadataCleaner.clean(edited)

        if let oldPath = original.filePath, let calibreID = book.calibreID,
           original.title != book.title || original.authors.first != book.authors.first {
            let oldFolder = root.appendingPathComponent((oldPath as NSString).deletingLastPathComponent, isDirectory: true)
            let newFolderPath = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
            let newFolder = root.appendingPathComponent(newFolderPath, isDirectory: true)
            let newName = CalibreLayout.fileName(title: book.title, authors: book.authors,
                                                 fileExtension: (oldPath as NSString).pathExtension)
            if newFolder.standardizedFileURL != oldFolder.standardizedFileURL {
                try FileManager.default.createDirectory(at: newFolder.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: oldFolder, to: newFolder)
                removeIfEmpty(oldFolder.deletingLastPathComponent())
                CoverImaging.forget(oldFolder.appendingPathComponent(CalibreLayout.coverFileName))
            }
            let oldFile = newFolder.appendingPathComponent((oldPath as NSString).lastPathComponent)
            let newFile = newFolder.appendingPathComponent(newName)
            if oldFile.lastPathComponent != newName {
                try FileManager.default.moveItem(at: oldFile, to: newFile)
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
