import Foundation

/// Abrir un libro en el lector (auditoría 7): qué hacer con una ventana de libro que la Mac vuelve
/// a abrir al arrancar y qué decir cuando el lector web no puede abrirlo.
public enum ReaderOpening {
    /// Una ventana de libro que la Mac restaura se queda solo si el libro sigue ahí: su archivo
    /// existe y, si era de la biblioteca, la biblioteca lo tiene. Mientras bajo la biblioteca de
    /// iCloud no la cierro (el libro puede llegar). Antes se abría en cada arranque con «Load failed»,
    /// sin la ventana de la biblioteca, y no dejaba salir de la app.
    /// `inLibrary` es nil si el libro no era de la biblioteca (un archivo suelto).
    public static func keepsRestoredWindow(fileExists: Bool, inLibrary: Bool?, waitingForCloud: Bool) -> Bool {
        guard fileExists else { return false }
        guard let inLibrary, !waitingForCloud else { return true }
        return inLibrary
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
