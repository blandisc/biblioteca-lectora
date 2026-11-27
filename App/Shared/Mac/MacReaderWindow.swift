#if os(macOS)
import AppKit
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
            #if DEBUG
            // Capturas: `-screenshot.readerSize 1400x900` abre el libro en una ventana ancha
            // (para ver que el renglón no se estira, MX-B).
            .task {
                guard let size = UserDefaults.standard.string(forKey: "screenshot.readerSize")?.split(separator: "x").compactMap({ Double($0) }),
                      size.count == 2 else { return }
                try? await Task.sleep(for: .seconds(1))
                NSApp.windows.first { $0.title == title }?.setContentSize(NSSize(width: size[0], height: size[1]))
            }
            #endif
    }

    private var title: String {
        book.bookID.flatMap { model.shelfBook(id: $0.uuidString)?.title } ?? book.url.deletingPathExtension().lastPathComponent
    }
}
#endif
