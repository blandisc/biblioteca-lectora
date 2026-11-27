import Foundation
import LectoraCore

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

/// Filtros rápidos de la Biblioteca: los mismos estados, con los mismos nombres y la misma
/// regla, que la barra lateral de la Mac (`ReadingState`, C1).
enum LibraryFilter: Hashable, Identifiable {
    case all
    case state(ReadingState)
    case series
    case cloud
    case duplicates
    var id: Self { self }

    /// Los estados siempre; «Abandonados», «Series», «Sin descargar» y «Posibles duplicados»
    /// solo si hay alguno, como en la Mac (antes salían vacíos y el último se cortaba).
    static func options(for books: [ShelfBook]) -> [LibraryFilter] {
        let states = ReadingState.allCases.filter { $0 != .abandoned }.map(LibraryFilter.state)
        let extra: [LibraryFilter] = [.state(.abandoned), .series, .cloud, .duplicates]
        return [.all] + states + extra.filter { filter in books.contains(where: filter.includes) }
    }

    var title: String {
        switch self {
        case .all: "Todos"
        case .state(let state): state.group
        case .series: "Series"
        case .cloud: "Sin descargar"
        case .duplicates: Duplicates.title
        }
    }

    func includes(_ book: ShelfBook) -> Bool {
        switch self {
        case .all: true
        case .state(let state): book.state == state
        case .series: book.series != nil
        case .cloud: book.inCloudOnly
        case .duplicates: book.possibleDuplicate
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

/// Para empujar la pantalla de un estante (CB-1).
struct ShelfRef: Hashable {
    let id: UUID
}
