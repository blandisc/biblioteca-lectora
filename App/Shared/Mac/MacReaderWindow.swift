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

    /// El archivo que abre el lector, decidido una vez al abrirse la ventana (auditoría 8, A1).
    @State private var file: URL?

    var body: some View {
        Group {
            if let file {
                ReaderView(bookFile: file, bookID: book.bookID, startCFI: book.startCFI)
            } else {
                Color.clear
            }
        }
            .frame(minWidth: Theme.Mac.readerMin.width, minHeight: Theme.Mac.readerMin.height)
            .navigationTitle(title)
            // Se decide una vez, al abrirse (auditoría 8, A1): antes se miraba en cada vuelta si el
            // archivo seguía en la ruta de cuando lo abriste, y la ventana se cerraba mientras leías
            // al identificar el libro, cambiar su autor, ordenar o mover el Gabinete.
            .task { await openOnce() }
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

    /// La ventana que abriste tú se queda siempre. Una que la Mac vuelve a abrir al arrancar, de un
    /// libro que ya no está (lo borraste o cambiaste de Gabinete), se cierra y abre la biblioteca
    /// (auditoría 7); mientras bajo tu biblioteca de iCloud, espero a saberlo.
    private func openOnce() async {
        guard file == nil else { return }
        guard !model.openedWindows.contains(book) else {
            file = currentFile
            return
        }
        while true {
            let url = currentFile
            let decision = ReaderOpening.restoredWindow(waitingForCloud: model.library.waitingForCloud,
                                                        inLibrary: book.bookID.map { model.library.book(id: $0) != nil },
                                                        fileExists: FileManager.default.fileExists(atPath: url.path),
                                                        inCloud: CloudFile.isPlaceholder(url))
            switch decision {
            case .keep:
                // Si sigue en iCloud, el lector lo baja antes de abrirlo (`CloudFiles.ensureDownloaded`).
                file = url
                return
            case .close:
                if !NSApp.windows.contains(where: { $0.isVisible && $0.identifier?.rawValue.hasPrefix(Self.libraryWindow) == true }) {
                    openWindow(id: Self.libraryWindow)
                }
                dismiss()
                return
            case .wait:
                try? await Task.sleep(for: CloudFiles.poll)
                if Task.isCancelled { return }
            }
        }
    }

    /// El archivo del libro ahora: el de la biblioteca (pudo cambiar de carpeta desde que lo
    /// abriste) o, si es un archivo suelto, el de siempre.
    private var currentFile: URL {
        book.bookID.flatMap { model.library.book(id: $0) }.flatMap { model.library.fileURL(for: $0) } ?? book.url
    }

    private var title: String {
        book.bookID.flatMap { model.shelfBook(id: $0.uuidString)?.title } ?? book.url.deletingPathExtension().lastPathComponent
    }
}
#endif
