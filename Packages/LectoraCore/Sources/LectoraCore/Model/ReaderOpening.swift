import Foundation

/// Abrir un libro en el lector (auditoría 7): qué hacer con una ventana de libro que la Mac vuelve
/// a abrir al arrancar y qué decir cuando el lector web no puede abrirlo.
public enum ReaderOpening {
    /// Qué hago con una ventana de libro que la Mac vuelve a abrir al arrancar.
    public enum RestoredWindow: Equatable, Sendable {
        /// Todavía bajo tu biblioteca de iCloud: el libro puede llegar. Espero y decido después.
        case wait
        /// Se queda y abre el libro (si su archivo está en iCloud, lo bajo).
        case keep
        /// Ya no está: la cierro y abro la biblioteca.
        case close
    }

    /// Lo decido una sola vez, al abrirse, y solo para una ventana restaurada (auditoría 8, A1): el
    /// libro que abriste tú ya está, y el que lees no se cierra porque cambie de carpeta (lo
    /// identificas, cambias su autor, ordenas o mueves el Gabinete). Un libro de la biblioteca se
    /// decide por si la biblioteca lo tiene, con el archivo de ahora (`fileURL(for:)`, no la ruta de
    /// cuando lo abriste); si su archivo sigue en iCloud cuenta como que está y lo bajo.
    /// `inLibrary` es nil si el libro no era de la biblioteca (un archivo suelto).
    /// Antes una ventana de un libro borrado se abría en cada arranque con «Load failed» (auditoría 7).
    public static func restoredWindow(waitingForCloud: Bool, inLibrary: Bool?, fileExists: Bool, inCloud: Bool) -> RestoredWindow {
        if waitingForCloud, inLibrary != nil { return .wait }
        if inLibrary == false { return .close }
        return fileExists || inCloud ? .keep : .close
    }

    /// Lo que dice el aviso «No pude abrir el libro», en español y en primera persona (regla 7):
    /// el lector web solo sabe decir «Load failed» o «File type not supported».
    public static func message(for raw: String?, fileExists: Bool) -> String {
        guard fileExists else { return missingFile }
        let text = (raw ?? "").lowercased()
        if ["not supported", "unsupported", "file type"].contains(where: text.contains) {
            return "No sé abrir este tipo de archivo. Gabinete lee EPUB, PDF, MOBI, AZW3, FB2 y CBZ."
        }
        if ["load failed", "failed to fetch", "not found", "network", "networkerror"].contains(where: text.contains) {
            return "No pude leer el archivo de este libro. Si está en iCloud, espera a que baje y vuelve a abrirlo."
        }
        return "No pude leer este libro: su archivo parece dañado. Prueba con otra copia."
    }

    /// El archivo ya no está donde lo dejé.
    public static let missingFile = "No encuentro el archivo de este libro: quizá lo moviste o lo borraste fuera de Gabinete."
}
