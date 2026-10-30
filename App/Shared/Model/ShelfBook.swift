import SwiftUI
import LectoraCore

/// Libro tal como lo muestra la interfaz, a partir de un `Book` del catálogo.
struct ShelfBook: Identifiable, Hashable {
    /// Estable para los libros importados (la ruta del archivo); aleatorio en los de ejemplo.
    var id = UUID().uuidString
    var title: String
    var author: String
    /// 0...1
    var progress: Double
    var addedDaysAgo: Int
    var inCloudOnly: Bool
    var cover: CoverStyle
    /// Archivo local, si el libro está en este dispositivo.
    var file: URL? = nil
    /// Línea de estado de la tarjeta de inicio («Cap. VII · 12 min para terminarlo»).
    var note: String? = nil
    /// Libros de la serie, si este libro la representa en la biblioteca.
    var seriesCount: Int? = nil
    /// La última frase que leíste, para «Donde lo dejaste».
    var lastSentence: String? = nil
    /// Libro del catálogo, si es real.
    var bookID: UUID? = nil
    /// `cover.jpg` del libro, si tiene.
    var coverImage: URL? = nil
    var series: String? = nil
    var seriesIndex: Double? = nil
    var addedAt: Date? = nil
    /// Primer autor como «Apellido, Nombre», para ordenar.
    var authorSort: String = ""
    /// Título sin artículo inicial, para ordenar y para el índice A–Z.
    var sortTitle: String = ""
    /// Última vez que lo abriste.
    var lastReadAt: Date? = nil

    var isReading: Bool { progress > 0 && progress < 1 }
    var isFinished: Bool { progress >= 1 }
    var isNew: Bool { addedDaysAgo < 7 && progress == 0 }

    /// Línea corta bajo la portada: «43 % · Cervantes», «Nuevo · Kahneman»…
    var caption: String {
        if isReading { return "\(Int(progress * 100)) % · \(author)" }
        if isFinished { return "Leído · \(author)" }
        if isNew { return "Nuevo · \(author)" }
        return author
    }
}

extension CoverStyle {
    /// Portada tipográfica para libros sin imagen: color fijo según el título.
    static func generated(for title: String) -> CoverStyle {
        // Doce tonos de cubierta bien separados entre sí (cálidos, fríos, claros y oscuros).
        let palette: [(UInt32, UInt32)] = [
            (0x2A2927, 0xEDEAE2), (0x3E4A6B, 0xEEF0F6), (0xC98B4E, 0x2B1A0E),
            (0x2F5D50, 0xF1EBDD), (0xE4C887, 0x2E2010), (0x5A2E2A, 0xF3E6D8),
            (0xD9D2C3, 0x1C1B19), (0x6B4E7A, 0xF1EAF4), (0x1F2A44, 0xE9DFC9),
            (0xB8C4B0, 0x1E261C), (0x9A3B2E, 0xF7E8E0), (0x4F6D7A, 0xEEF3F5),
        ]
        // FNV-1a: títulos parecidos caen en colores distintos.
        var hash: UInt32 = 2_166_136_261
        for scalar in title.unicodeScalars { hash = (hash ^ scalar.value) &* 16_777_619 }
        let index = Int(hash % UInt32(palette.count))
        return CoverStyle(background: Color(hex: palette[index].0), foreground: Color(hex: palette[index].1))
    }
}

extension ShelfBook {
    /// Libro de la biblioteca real.
    @MainActor
    init(book: Book, library: LibraryStore, seriesCount: Int? = nil) {
        let position = library.position(for: book.id)
        let progress = book.readingStatus == .finished ? 1 : (position?.fraction ?? 0)
        let days = book.addedAt.map { Int(Date().timeIntervalSince($0) / 86_400) } ?? 999
        self.init(
            id: book.id.uuidString,
            title: book.title,
            author: book.authors.isEmpty ? "Autor desconocido" : book.authors.joined(separator: ", "),
            progress: progress,
            addedDaysAgo: days,
            // En iCloud Drive con «Optimizar almacenamiento», el libro puede no estar bajado.
            inCloudOnly: library.fileURL(for: book).map { !CloudFiles.isDownloaded($0) } ?? false,
            cover: .generated(for: book.title),
            file: library.fileURL(for: book),
            note: book.series.map { series in
                book.seriesIndex.map { "\(series) · \(Self.number($0))" } ?? series
            } ?? "Listo para leer",
            seriesCount: seriesCount,
            lastSentence: position?.excerpt,
            bookID: book.id,
            coverImage: library.coverURL(for: book),
            series: book.series,
            seriesIndex: book.seriesIndex,
            addedAt: book.addedAt,
            authorSort: book.authors.first.map(Book.authorSort) ?? "",
            sortTitle: book.sortTitle,
            lastReadAt: position?.updatedAt
        )
    }

    static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
