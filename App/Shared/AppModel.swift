import SwiftUI

/// Libro abierto en el lector.
struct OpenBook: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Estado compartido de la app. Provisional: mezcla los libros importados con
/// la biblioteca de ejemplo hasta que entre LectoraCore (S3).
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var localBooks: [URL] = LocalBooks.recentBooks()
    @Published var importing = false
    @Published var openBook: OpenBook?
    @Published var importError: String?

    var shelf: [ShelfBook] {
        localBooks.map(ShelfBook.init(file:)) + SampleLibrary.books
    }

    /// El libro de la tarjeta de inicio: el último importado o, si no hay, el de ejemplo.
    var currentBook: ShelfBook {
        localBooks.first.map(ShelfBook.init(file:)) ?? SampleLibrary.current
    }

    var desk: [ShelfBook] {
        Array((localBooks.dropFirst().map(ShelfBook.init(file:)) + SampleLibrary.desk).prefix(6))
    }

    /// Abre el libro si está en este dispositivo; si no, devuelve `false`.
    @discardableResult
    func open(_ book: ShelfBook) -> Bool {
        guard let file = book.file else { return false }
        openBook = OpenBook(url: file)
        return true
    }

    func continueReading() {
        if !open(currentBook) { importing = true }
    }

    func finishImport(_ result: Result<URL, Error>) {
        do {
            let local = try LocalBooks.importBook(from: result.get())
            localBooks = LocalBooks.recentBooks()
            openBook = OpenBook(url: local)
        } catch {
            importError = error.localizedDescription
        }
    }
}
