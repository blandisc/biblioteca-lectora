import Foundation

/// Portadas de internet sin repetir (auditoría 8: en Rayuela salía la misma cuatro veces, y la
/// que ya tiene el libro salía otra vez como «Internet»). Primero por su dirección, sin lo que
/// no cambia la imagen (el tamaño pedido, `default=false`, `http` o `https`); luego, ya bajadas,
/// por sus bytes: dos direcciones distintas dan a veces la misma imagen.
public enum CoverDedupe {
    /// Lo que identifica la imagen de una dirección: en Open Library, su número sin el tamaño
    /// (`/b/id/123-L.jpg` = `/b/id/123-M.jpg`); en Google Books, el id del libro.
    public static func key(_ url: URL) -> String {
        let host = (url.host ?? "").lowercased()
        let path = url.path
        if host.hasSuffix("openlibrary.org") {
            let file = (path as NSString).deletingPathExtension
            let bare = file.replacingOccurrences(of: #"-[SML]$"#, with: "", options: .regularExpression)
            return "openlibrary:" + bare.lowercased()
        }
        if host.contains("books.google") || host.hasSuffix("googleusercontent.com") {
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
                ?? path.components(separatedBy: "/").last { !$0.isEmpty }
            if let id { return "google:" + id }
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&") ?? ""
        return host + path + (query.isEmpty ? "" : "?" + query)
    }

    /// Las direcciones en su orden, sin dos que den la misma imagen.
    public static func distinct(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert(key($0)).inserted }
    }

    /// Ya bajadas (con los bytes como se guardarían, así se comparan con la portada de ahora):
    /// sin las que no bajaron, sin las de bytes repetidos y sin la que ya tiene el libro.
    public static func distinct(_ downloaded: [(url: URL, data: Data?)], current: Data?) -> [URL] {
        var seen = Set<Data>()
        if let current { seen.insert(current) }
        return downloaded.compactMap { item in
            guard let data = item.data, seen.insert(data).inserted else { return nil }
            return item.url
        }
    }
}
