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
    let annotations: AnnotationStore
    @Published var importing = false
    @Published var openBook: OpenBook?
    /// Resumen de una importación con duplicados o errores.
    @Published var importReport: String?
    /// Libro que suena en el mini reproductor. Por ahora solo la interfaz: el audio llega con el modo audiolibro.
    @Published var listening: ShelfBook?
    private var observations: [AnyCancellable] = []

    init(library: LibraryStore? = nil, annotations: AnnotationStore? = nil) {
        self.library = library ?? .shared
        self.annotations = annotations ?? .shared
        observations = [
            // La estantería se recalcula una vez por cambio de la biblioteca, no en cada vista.
            self.library.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async { self?.rebuildShelf() }
            },
            self.annotations.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() },
        ]
        rebuildShelf()
        if LaunchOptions.listening { listening = currentBook }
    }

    /// Todos los libros, en el orden del catálogo.
    @Published private(set) var shelf: [ShelfBook] = []
    private var shelfByID: [String: ShelfBook] = [:]
    /// Los más recientes primero (lo último que añadiste).
    private var recent: [ShelfBook] = []

    private func rebuildShelf() {
        shelf = library.books.map { ShelfBook(book: $0, library: library) }
        shelfByID = Dictionary(uniqueKeysWithValues: shelf.map { ($0.id, $0) })
        recent = LibrarySort.recent.sorted(shelf)
    }

    func shelfBook(id: String) -> ShelfBook? { shelfByID[id] }

    /// El libro de la Mesa: el último que abriste o, si aún no lees ninguno, el último que añadiste.
    var currentBook: ShelfBook? {
        shelf.filter { $0.lastReadAt != nil }.max { $0.lastReadAt! < $1.lastReadAt! } ?? recent.first
    }

    /// Lo siguiente en la pila: los más recientes, sin el actual.
    var desk: [ShelfBook] {
        let current = currentBook?.id
        return Array(recent.filter { $0.id != current }.prefix(6))
    }

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
        seedSampleHighlights()
        rebuildShelf()
        if LaunchOptions.listening { listening = currentBook }
    }

    /// Subrayados de muestra para que el Cuaderno no salga vacío en las capturas.
    private func seedSampleHighlights() {
        let samples: [(String, String, String?)] = [
            ("Don Quijote de la Mancha", "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero.", nil),
            ("Don Quijote de la Mancha", "Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza.", "Así presenta Cervantes a su héroe: sin épica."),
            ("Rayuela", "Una olla de algo más vaca que carnero, salpicón las más noches.", nil),
        ]
        for (title, quote, note) in samples {
            guard let book = library.books.first(where: { $0.title == title }) else { continue }
            try? annotations.save(Annotation(bookID: book.id, cfi: nil, quote: quote, color: "pencil", note: note))
        }
    }
}
