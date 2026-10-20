import Combine
import LectoraCore
import SwiftUI

/// Libro abierto en el lector.
struct OpenBook: Identifiable {
    let url: URL
    var bookID: UUID?
    /// Si se abrió desde la portada de la Mesa: el libro «sale» de esa portada.
    var fromCover = false
    var id: URL { url }
}

/// Estado compartido de la app, sobre la biblioteca real (`LibraryStore`).
@MainActor
final class AppModel: ObservableObject {
    let library: LibraryStore
    @Published var importing = false
    @Published var openBook: OpenBook?
    /// Resumen de una importación con duplicados o errores.
    @Published var importReport: String?
    /// Libro que suena en el mini reproductor. Por ahora solo la interfaz: el audio llega con el modo audiolibro.
    @Published var listening: ShelfBook?
    private var observation: AnyCancellable?

    init(library: LibraryStore? = nil) {
        self.library = library ?? .shared
        observation = library.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        if LaunchOptions.listening { listening = currentBook }
    }

    /// Todos los libros, en el orden del catálogo.
    var shelf: [ShelfBook] {
        library.books.map { ShelfBook(book: $0, library: library) }
    }

    /// Los más recientes primero (lo último que añadiste).
    private var recent: [ShelfBook] {
        library.books
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .map { ShelfBook(book: $0, library: library) }
    }

    /// El libro de la Mesa: por ahora, el último que añadiste.
    var currentBook: ShelfBook? { recent.first }

    var desk: [ShelfBook] { Array(recent.dropFirst().prefix(6)) }

    func book(for shelfBook: ShelfBook) -> Book? {
        shelfBook.bookID.flatMap(library.book(id:))
    }

    /// Abre el libro si está en este dispositivo; si no, devuelve `false`.
    @discardableResult
    func open(_ book: ShelfBook, fromCover: Bool = false) -> Bool {
        guard let file = book.file else { return false }
        openBook = OpenBook(url: file, bookID: book.bookID, fromCover: fromCover)
        return true
    }

    func continueReading() {
        if let book = currentBook, open(book, fromCover: true) { return }
        importing = true
    }

    func finishImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importReport = error.localizedDescription
        case .success(let urls):
            Task { await importBooks(urls) }
        }
    }

    func importBooks(_ urls: [URL]) async {
        let results = await library.importFiles(urls)
        var duplicates: [String] = []
        var failures = 0
        for result in results {
            switch result {
            case .success(.duplicate(let book)): duplicates.append(book.title)
            case .failure: failures += 1
            default: break
            }
        }
        var lines: [String] = []
        if !duplicates.isEmpty {
            lines.append(duplicates.count == 1
                ? "«\(duplicates[0])» ya estaba en tu biblioteca."
                : "\(duplicates.count) libros ya estaban en tu biblioteca.")
        }
        if failures > 0 {
            lines.append(failures == 1 ? "Un archivo no se pudo leer." : "\(failures) archivos no se pudieron leer.")
        }
        if !lines.isEmpty { importReport = lines.joined(separator: " ") }
    }

    /// Capturas automáticas: importa los libros de `Documents/Semilla` si la biblioteca está vacía.
    func seedForScreenshotsIfNeeded() async {
        guard LaunchOptions.seed, library.books.isEmpty else { return }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Semilla", isDirectory: true)
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        await library.importFiles(files)
        try? FileManager.default.removeItem(at: folder)
        if LaunchOptions.listening { listening = currentBook }
    }
}
