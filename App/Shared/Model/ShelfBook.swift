import SwiftUI

/// Libro tal como lo muestra la interfaz: de la biblioteca real (`Book` de
/// LectoraCore) o de ejemplo (Cuaderno y estilo Nativo).
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

enum SampleLibrary {
    static let current = ShelfBook(
        title: "Don Quijote de la Mancha", author: "Miguel de Cervantes",
        progress: 0.43, addedDaysAgo: 40, inCloudOnly: false,
        cover: CoverStyle(background: Color(hex: 0xE4C887), foreground: Color(hex: 0x2E2010), illustration: .windmill),
        note: "Cap. VII · 12 min para terminarlo",
        lastSentence: "…y proseguía en sus voces y en sus desatinos, dando cuchilladas a todas partes."
    )

    static let books: [ShelfBook] = [
        current,
        ShelfBook(title: "Pensar rápido, pensar despacio", author: "Daniel Kahneman", progress: 0, addedDaysAgo: 0, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0xF6F4EE), foreground: Color(hex: 0x1C1B19), illustration: .circles, bordered: true)),
        ShelfBook(title: "Meditaciones", author: "Marco Aurelio", progress: 0.12, addedDaysAgo: 12, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0x2A2927), foreground: Color(hex: 0xEDEAE2))),
        ShelfBook(title: "Fundación", author: "Isaac Asimov", progress: 0, addedDaysAgo: 3, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0x3E4A6B), foreground: Color(hex: 0xEEF0F6), illustration: .rings),
                  seriesCount: 7),
        ShelfBook(title: "Rayuela", author: "Julio Cortázar", progress: 0.68, addedDaysAgo: 90, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0xF1EEE7), foreground: Color(hex: 0x1C1B19), bordered: true)),
        ShelfBook(title: "Pedro Páramo", author: "Juan Rulfo", progress: 1, addedDaysAgo: 200, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0x8C6A4F), foreground: Color(hex: 0xF6EEE6))),
        ShelfBook(title: "Sapiens", author: "Yuval Noah Harari", progress: 0.27, addedDaysAgo: 25, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0xD9D2C3), foreground: Color(hex: 0x1C1B19), illustration: .circles)),
        ShelfBook(title: "Cien años de soledad", author: "Gabriel García Márquez", progress: 0, addedDaysAgo: 30, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0x2F5D50), foreground: Color(hex: 0xF1EBDD))),
        ShelfBook(title: "Dune", author: "Frank Herbert", progress: 0, addedDaysAgo: 15, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0xC98B4E), foreground: Color(hex: 0x2B1A0E), illustration: .rings)),
        ShelfBook(title: "Ficciones", author: "Jorge Luis Borges", progress: 1, addedDaysAgo: 300, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0x1F2A44), foreground: Color(hex: 0xE9DFC9), illustration: .rings)),
        ShelfBook(title: "La sombra del viento", author: "Carlos Ruiz Zafón", progress: 0, addedDaysAgo: 60, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0x5A2E2A), foreground: Color(hex: 0xF3E6D8))),
        ShelfBook(title: "Thinking in Systems", author: "Donella H. Meadows", progress: 0, addedDaysAgo: 120, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0xEEF0F2), foreground: Color(hex: 0x1C1B19), illustration: .circles, bordered: true)),
    ]

    /// «En tu mesa»: lo que estás leyendo y lo recién llegado, sin el libro actual.
    static var desk: [ShelfBook] {
        books.filter { $0 != current && ($0.isReading || $0.isNew || $0.addedDaysAgo < 7) }
    }
}

extension CoverStyle {
    /// Portada tipográfica para libros sin imagen: color fijo según el título.
    static func generated(for title: String) -> CoverStyle {
        let palette: [(UInt32, UInt32)] = [
            (0x2A2927, 0xEDEAE2), (0x3E4A6B, 0xEEF0F6), (0x8C6A4F, 0xF6EEE6),
            (0x56634F, 0xF1F2EC), (0xE4C887, 0x2E2010), (0x5A2E2A, 0xF3E6D8),
            (0x2F5D50, 0xF1EBDD), (0xD9D2C3, 0x1C1B19),
        ]
        let index = title.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 997 } % palette.count
        return CoverStyle(background: Color(hex: palette[index].0), foreground: Color(hex: palette[index].1))
    }
}

extension ShelfBook {
    /// Libro de la biblioteca real.
    @MainActor
    init(book: Book, library: LibraryStore, seriesCount: Int? = nil) {
        let days = book.addedAt.map { Int(Date().timeIntervalSince($0) / 86_400) } ?? 999
        self.init(
            id: book.id.uuidString,
            title: book.title,
            author: book.authors.isEmpty ? "Autor desconocido" : book.authors.joined(separator: ", "),
            progress: book.readingStatus == .finished ? 1 : 0,
            addedDaysAgo: days,
            inCloudOnly: false,
            cover: .generated(for: book.title),
            file: library.fileURL(for: book),
            note: book.series.map { series in
                book.seriesIndex.map { "\(series) · \(Self.number($0))" } ?? series
            } ?? "Listo para leer",
            seriesCount: seriesCount,
            bookID: book.id,
            coverImage: library.coverURL(for: book),
            series: book.series,
            seriesIndex: book.seriesIndex
        )
    }

    static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
