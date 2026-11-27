import Foundation

/// Por qué no entraron los archivos que elegiste, agrupado por su porqué (auditoría 7, M3). Antes,
/// con varios, siempre decía «No los pude abrir como libros», también cuando no los añadí porque
/// bajaba tu biblioteca de iCloud o estaba ordenándola.
public enum ImportFailure: Equatable, Sendable {
    /// No es un libro que se pueda abrir.
    case unreadable(name: String)
    /// Un archivo de ese libro sigue en iCloud sin bajar.
    case stillDownloading(title: String)
    /// No lo añadí por otra razón (bajo tu biblioteca, otro trabajo corre…): su frase.
    case refused(reason: String)

    /// Una frase por cada porqué, en el orden en que aparecen; de cada uno, los primeros
    /// `preview` nombres.
    public static func lines(_ failures: [ImportFailure], preview: Int) -> [String] {
        // Cada porqué con sus nombres (o cuántos), en el orden en que llegó.
        var groups: [(kind: ImportFailure, names: [String])] = []
        for failure in failures {
            let (kind, name): (ImportFailure, String) = switch failure {
            case .unreadable(let name): (.unreadable(name: ""), name)
            case .stillDownloading(let title): (.stillDownloading(title: ""), title)
            case .refused: (failure, "")
            }
            if let index = groups.firstIndex(where: { $0.kind == kind }) {
                groups[index].names.append(name)
            } else {
                groups.append((kind, [name]))
            }
        }
        func named(_ names: [String]) -> String {
            names.prefix(preview).map { "«\($0)»" }.joined(separator: ", ") + (names.count > preview ? "…" : "")
        }
        return groups.map { kind, names in
            switch kind {
            case .unreadable:
                names.count == 1
                    ? "«\(names[0])» no entró a tu biblioteca: no lo pude abrir como libro."
                    : "\(names.count.counted("archivo no entró", "archivos no entraron")) a tu biblioteca: \(named(names)). No los pude abrir como libros."
            case .stillDownloading:
                names.count == 1
                    ? "Todavía estoy bajando de iCloud un archivo de «\(names[0])». Vuelve a intentarlo en un momento."
                    : "Todavía estoy bajando de iCloud archivos de \(names.count.counted("libro", "libros")): \(named(names)). Vuelve a intentarlo en un momento."
            case .refused(let reason):
                "No añadí \(names.count.counted("archivo", "archivos")). \(reason)"
            }
        }
    }
}
