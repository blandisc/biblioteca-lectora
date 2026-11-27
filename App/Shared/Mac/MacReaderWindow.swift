#if os(macOS)
import SwiftUI

/// Un libro en su propia ventana de Mac (MG-1): con la biblioteca al lado, varios abiertos a
/// la vez y el nombre del libro en la barra. Cerrar la ventana (⌘W) es cerrar el libro.
struct MacReaderWindow: View {
    static let id = "libro"
    let book: OpenBook
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ReaderView(bookFile: book.url, bookID: book.bookID, startCFI: book.startCFI)
            .frame(minWidth: Theme.Mac.readerMin.width, minHeight: Theme.Mac.readerMin.height)
            .navigationTitle(title)
    }

    private var title: String {
        book.bookID.flatMap { model.shelfBook(id: $0.uuidString)?.title } ?? book.url.deletingPathExtension().lastPathComponent
    }
}
#endif
