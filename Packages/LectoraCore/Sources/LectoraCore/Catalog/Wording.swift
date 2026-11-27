import Foundation

// Las mismas palabras y reglas en el iPhone y en la Mac (SD-3, 26 nov 2026): lo que se
// nombra igual en las dos sale de aquí, una sola vez.

extension Int {
    /// «1 libro», «1,250 libros», «0 notas»: la cifra concuerda con lo que cuenta, igual en
    /// toda la app y en el paquete (26 nov 2026: la Mac decía «Renombrar en 1 libros»).
    /// `shown` es la cifra ya escrita de otra forma («4,4 mil palabras»).
    public func counted(_ one: String, _ many: String, shown: String? = nil) -> String {
        "\(shown ?? formatted(.number.locale(Locale(identifier: "es_MX")))) \(self == 1 ? one : many)"
    }

    /// Lo mismo, o nada si es cero: para unir partes («1 libro · 4 subrayados»).
    public func countedIfAny(_ one: String, _ many: String) -> String? {
        self == 0 ? nil : counted(one, many)
    }
}

/// En qué va un libro: el mismo nombre y la misma regla en la Biblioteca del iPhone, la
/// barra lateral y la tabla de la Mac, y la ficha de los dos (C1). Antes el iPhone decía
/// «En curso / Sin empezar» por el avance y la Mac «Leyendo / Por leer» por el estado, y un
/// libro marcado «Leyendo» sin avance caía en grupos distintos.
public enum ReadingState: String, CaseIterable, Sendable {
    case reading, toRead, finished, abandoned

    /// Lo marcado a mano manda; si no, el avance: empezado es «Leyendo», al final es «Leído».
    public init(_ status: ReadingStatus, progress: Double) {
        switch status {
        case .abandoned: self = .abandoned
        case .finished: self = .finished
        case _ where progress >= 1: self = .finished
        case _ where progress > 0: self = .reading
        case .reading: self = .reading
        case .toRead: self = .toRead
        }
    }

    /// El estado de un libro («Leído»).
    public var name: String {
        switch self {
        case .reading: "Leyendo"
        case .toRead: "Por leer"
        case .finished: "Leído"
        case .abandoned: "Abandonado"
        }
    }

    /// El grupo de libros en ese estado («Leídos»), en filtros y en la barra lateral.
    public var group: String {
        switch self {
        case .reading: "Leyendo"
        case .toRead: "Por leer"
        case .finished: "Leídos"
        case .abandoned: "Abandonados"
        }
    }

    /// El mismo símbolo en los dos (cada uno con un solo significado).
    public var symbol: String {
        switch self {
        case .reading: "book.pages"
        case .toRead: "text.book.closed"
        case .finished: "checkmark.circle"
        case .abandoned: "xmark.circle"
        }
    }

    /// El botón para abrir el libro: el mismo en la Mesa, la ficha y la Mac.
    public var openAction: String {
        switch self {
        case .reading: "Seguir leyendo"
        case .finished: "Leer otra vez"
        case .toRead, .abandoned: "Empezar a leer"
        }
    }

    /// Lo que se guarda en el libro al elegir el estado a mano.
    public var status: ReadingStatus {
        switch self {
        case .reading: .reading
        case .toRead: .toRead
        case .finished: .finished
        case .abandoned: .abandoned
        }
    }

    public init(_ status: ReadingStatus) {
        self.init(status, progress: 0)
    }
}

/// Los datos de un libro que se escriben como texto, iguales en los dos formularios (C2).
public enum BookFields {
    /// Los autores se separan con « & », como en Calibre: «García Márquez, Gabriel» es uno solo.
    public static let authorSeparator = " & "
    /// Las etiquetas, con comas.
    public static let tagSeparator = ", "

    public static func authorsText(_ authors: [String]) -> String {
        authors.joined(separator: authorSeparator)
    }

    public static func authors(_ text: String) -> [String] {
        text.components(separatedBy: "&").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func tagsText(_ tags: [String]) -> String {
        tags.joined(separator: tagSeparator)
    }

    public static func tags(_ text: String) -> [String] {
        text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// El idioma con su nombre en español («Español», no «es»), igual en toda la app (UX-3c):
    /// también «es-MX», «es_ES» o «spa» dicen «Español», y con mayúscula solo al principio
    /// («Chino mandarín»). Lo que no se reconoce, tal cual.
    public static func languageName(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        let base = trimmed.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? trimmed
        guard let name = Locale(identifier: "es").localizedString(forLanguageCode: base.lowercased()), !base.isEmpty
        else { return code }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Lo que dice un campo cuando los libros elegidos tienen valores distintos.
    public static let mixed = "Valores distintos"
}

/// Lo que se hace con el texto elegido en el libro: el mismo nombre y el mismo símbolo en
/// la barra del iPhone, el menú de la Mac y la tarjeta de un subrayado (C10). Cortos, porque
/// en el iPhone caben cinco en un renglón.
public enum SelectionAction: CaseIterable, Sendable {
    case highlight, note, toNote, lookup, copy

    public var title: String {
        switch self {
        case .highlight: "Subrayar"
        case .note: "Nota"
        case .toNote: "A una nota"
        case .lookup: "Consultar"
        case .copy: "Copiar"
        }
    }

    public var symbol: String {
        switch self {
        case .highlight: "pencil.line"
        case .note: "square.and.pencil"
        case .toNote: "note.text.badge.plus"
        case .lookup: "character.book.closed"
        case .copy: "doc.on.doc"
        }
    }
}

/// Las acciones sobre la biblioteca que existen en las dos plataformas: un nombre y un símbolo
/// cada una (C6, C7). Antes agregar libros tenía cinco nombres («Añadir libro», «Importar
/// libros»…) y buscar datos otros cinco, con un globo que en la Mac quería decir «Idiomas».
public enum LibraryAction: CaseIterable, Sendable {
    case addBooks, findData

    public var title: String {
        switch self {
        case .addBooks: "Añadir libros"
        case .findData: "Buscar datos en internet"
        }
    }

    public var symbol: String {
        switch self {
        case .addBooks: "plus"
        case .findData: "wand.and.stars"
        }
    }

    /// Con varios libros: «Buscar datos de 3 libros».
    public static func findData(count: Int) -> String {
        count == 1 ? LibraryAction.findData.title : "Buscar datos de \(count.counted("libro", "libros"))"
    }
}

/// Buscar (UX-4f): el mismo nombre en la pestaña, el título, la barra de la Mac y lo que dice el
/// campo vacío, que empieza igual («Buscar en…»), como «Buscar en el libro» dentro de un libro.
public enum SearchWording {
    public static let title = "Buscar"
    public static let prompt = "Buscar en libros, subrayados y notas"
    public static let inBook = "Buscar en el libro"
}

/// Los libros que parecen estar dos veces (CB-3, UX-2d): el mismo nombre y el mismo ícono en el
/// filtro y la marca del iPhone y en la sección de la Mac (regla 8).
public enum Duplicates {
    public static let title = "Posibles duplicados"
    public static let one = "Posible duplicado"
    public static let symbol = "square.on.square"
}

/// Los rótulos del formulario de datos de un libro, iguales en la hoja del iPhone y en la
/// ficha de la Mac (C2): las mismas secciones, en el mismo orden.
public enum BookSection: String, CaseIterable, Sendable {
    case book = "Libro"
    case edition = "Edición"
    case reading = "Tu lectura"
    case summary = "Sinopsis"
}

extension BookFields {
    /// Cómo se escribe la fecha de publicación.
    public static let publishedPrompt = "2016 o 2016-05-01"
    /// Los idiomas que se eligen de una lista; los demás, si un libro los trae, se agregan.
    public static let languages = ["es", "en"]

    /// El ISBN se guarda solo con sus cifras (y la X final), igual en los dos.
    public static func isbn(_ text: String) -> String? {
        let clean = text.uppercased().filter { $0.isNumber || $0 == "X" }
        return clean.isEmpty ? nil : clean
    }
}

/// El dispositivo donde corre Gabinete, dicho por su nombre (auditoría 2, 27 nov 2026): la
/// bienvenida decía «Archivos › En mi iPhone» también en la Mac y en el iPad, y la carpeta
/// local se llamaba «En este iPhone» en el iPad. Toda pantalla compartida lo dice con esto
/// (regla 8), nunca con «iPhone» escrito a mano.
public enum DeviceKind: String, CaseIterable, Sendable {
    case iPhone, iPad, mac

    /// «iPhone», «iPad», «Mac».
    public var name: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        }
    }

    /// «En este iPhone», «En este iPad», «En esta Mac».
    public var here: String { self == .mac ? "En esta Mac" : "En este \(name)" }

    /// Su dibujo, el mismo en la bienvenida y en Ajustes › Tu Gabinete.
    public var symbol: String {
        switch self {
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .mac: "desktopcomputer"
        }
    }

    /// Dónde queda la carpeta del Gabinete cuando vive en el dispositivo, como la encuentras.
    public var localFolder: String {
        switch self {
        case .iPhone, .iPad: "Archivos › En mi \(name) › Gabinete"
        // En la Mac la app vive en su espacio propio (sandbox): no hay ruta corta que enseñar.
        case .mac: "En la carpeta propia de Gabinete en tu Mac"
        }
    }

    /// Dónde están tus archivos para añadirlos: «Archivos» en el iPhone y el iPad, el Finder en la Mac.
    public var files: String { self == .mac ? "el Finder" : "Archivos" }

    /// El otro dispositivo con el que suele compartir la carpeta en iCloud Drive.
    public var partner: DeviceKind { self == .mac ? .iPhone : .mac }
}
