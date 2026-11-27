#if os(macOS)
import AppKit
import LectoraCore
import SwiftUI

/// Un libro en su propia ventana de Mac (MG-1): con la biblioteca al lado, varios abiertos a
/// la vez y el nombre del libro en la barra. Cerrar la ventana (⌘W) es cerrar el libro.
struct MacReaderWindow: View {
    static let id = "libro"
    let book: OpenBook
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if available {
                ReaderView(bookFile: book.url, bookID: book.bookID, startCFI: book.startCFI)
            } else {
                Color.clear
            }
        }
            .frame(minWidth: Theme.Mac.readerMin.width, minHeight: Theme.Mac.readerMin.height)
            .navigationTitle(title)
            // Una ventana que la Mac vuelve a abrir al arrancar, de un libro que ya no está (lo
            // borraste o cambiaste de Gabinete): la cierro y abro la biblioteca (auditoría 7). Antes
            // se abría en cada arranque con «Load failed», sin la biblioteca, y no dejaba salir.
            .task(id: available) {
                guard !available else { return }
                if !NSApp.windows.contains(where: { $0.isVisible && $0.identifier?.rawValue.hasPrefix(Self.libraryWindow) == true }) {
                    openWindow(id: Self.libraryWindow)
                }
                dismiss()
            }
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

    /// El `id` de la ventana de la biblioteca (`LectoraApp`).
    static let libraryWindow = "biblioteca"

    /// El libro sigue ahí: su archivo existe y la biblioteca lo tiene.
    private var available: Bool {
        ReaderOpening.keepsRestoredWindow(fileExists: FileManager.default.fileExists(atPath: book.url.path),
                                          inLibrary: book.bookID.map { model.library.book(id: $0) != nil },
                                          waitingForCloud: model.library.waitingForCloud)
    }

    private var title: String {
        book.bookID.flatMap { model.shelfBook(id: $0.uuidString)?.title } ?? book.url.deletingPathExtension().lastPathComponent
    }
}
#endif
