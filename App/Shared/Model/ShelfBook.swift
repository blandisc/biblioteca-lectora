import SwiftUI

/// Libro tal como lo muestra la interfaz. Por ahora con datos de ejemplo;
/// después se alimenta de LectoraCore (biblioteca sincronizada).
struct ShelfBook: Identifiable, Hashable {
    let id = UUID()
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
        note: "Cap. VII · 12 min para terminarlo"
    )

    static let books: [ShelfBook] = [
        current,
        ShelfBook(title: "Pensar rápido, pensar despacio", author: "Daniel Kahneman", progress: 0, addedDaysAgo: 0, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0xF6F4EE), foreground: Theme.ink, illustration: .circles, bordered: true)),
        ShelfBook(title: "Meditaciones", author: "Marco Aurelio", progress: 0.12, addedDaysAgo: 12, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0x2A2927), foreground: Color(hex: 0xEDEAE2))),
        ShelfBook(title: "Fundación", author: "Isaac Asimov", progress: 0, addedDaysAgo: 3, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0x3E4A6B), foreground: Color(hex: 0xEEF0F6), illustration: .rings)),
        ShelfBook(title: "Rayuela", author: "Julio Cortázar", progress: 0.68, addedDaysAgo: 90, inCloudOnly: true,
                  cover: CoverStyle(background: Color(hex: 0xF1EEE7), foreground: Theme.ink, bordered: true)),
        ShelfBook(title: "Pedro Páramo", author: "Juan Rulfo", progress: 1, addedDaysAgo: 200, inCloudOnly: false,
                  cover: CoverStyle(background: Color(hex: 0x8C6A4F), foreground: Color(hex: 0xF6EEE6))),
    ]

    /// «En tu mesa»: lo que estás leyendo y lo recién llegado, sin el libro actual.
    static var desk: [ShelfBook] {
        books.filter { $0 != current && ($0.isReading || $0.isNew || $0.addedDaysAgo < 7) }
    }
}

extension ShelfBook {
    /// Libro importado a este dispositivo. Sin metadatos todavía: el título sale
    /// del nombre de archivo y la portada de una paleta fija.
    init(file: URL) {
        let name = file.deletingPathExtension().lastPathComponent
        let palette: [(UInt32, UInt32)] = [
            (0x2A2927, 0xEDEAE2), (0x3E4A6B, 0xEEF0F6), (0x8C6A4F, 0xF6EEE6),
            (0x56634F, 0xF1F2EC), (0xE4C887, 0x2E2010),
        ]
        let index = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 997 } % palette.count
        self.init(
            title: name, author: "En este dispositivo",
            progress: 0, addedDaysAgo: 0, inCloudOnly: false,
            cover: CoverStyle(background: Color(hex: palette[index].0), foreground: Color(hex: palette[index].1)),
            file: file, note: "Listo para leer"
        )
    }
}
