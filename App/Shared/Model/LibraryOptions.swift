import Foundation

/// Orden de la Biblioteca.
enum LibrarySort: String, CaseIterable, Identifiable {
    case recent = "Recientes"
    case title = "Título"
    case author = "Autor"
    case progress = "Avance"
    var id: Self { self }

    func sorted(_ books: [ShelfBook]) -> [ShelfBook] {
        switch self {
        case .recent: books.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        case .title: books.sorted { $0.sortTitle.localizedStandardCompare($1.sortTitle) == .orderedAscending }
        case .author: books.sorted { $0.authorSort.localizedStandardCompare($1.authorSort) == .orderedAscending }
        case .progress: books.sorted { $0.progress > $1.progress }
        }
    }
}

/// Portadas o lista.
enum LibraryLayout: String, CaseIterable, Identifiable {
    case covers = "Portadas"
    case list = "Lista"
    var id: Self { self }
}

/// Filtros rápidos de la Biblioteca.
enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case reading = "En curso"
    case unread = "Sin empezar"
    case series = "Series"
    case cloud = "Sin descargar"
    var id: Self { self }

    func includes(_ book: ShelfBook) -> Bool {
        switch self {
        case .all: true
        case .reading: book.isReading
        case .unread: book.progress == 0
        case .series: book.series != nil
        case .cloud: book.inCloudOnly
        }
    }
}

/// Una serie, abierta desde su pila de portadas. Se distingue por autor: dos
/// «Trilogía» de autores distintos no se mezclan.
struct SeriesRef: Hashable {
    let name: String
    let authorSort: String

    init(name: String, authorSort: String) {
        self.name = name
        self.authorSort = authorSort
    }

    init?(_ book: ShelfBook) {
        guard let series = book.series else { return nil }
        self.init(name: series, authorSort: book.authorSort)
    }

    func contains(_ book: ShelfBook) -> Bool {
        book.series == name && book.authorSort == authorSort
    }
}

enum LibraryKeys {
    static let sort = "library.sort"
    static let layout = "library.layout"
}
