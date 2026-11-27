import Foundation

/// Opciones de arranque para las capturas automáticas (scripts/screenshots.sh).
/// Llegan como argumentos `-clave valor`, que iOS guarda en UserDefaults.
enum LaunchOptions {
    /// Pestaña inicial: reading, library, notebook o search.
    static var tab: String? { UserDefaults.standard.string(forKey: "screenshot.tab") }
    /// Abrir el primer libro importado al arrancar.
    static var opensFirstBook: Bool { UserDefaults.standard.bool(forKey: "screenshot.openFirst") }
    /// Con `openFirst`: abrir el libro cuyo título contiene esto (`-screenshot.book Rayuela`).
    static var book: String? { UserDefaults.standard.string(forKey: "screenshot.book") }
    /// Abrir el lector con los controles escondidos.
    static var hidesReaderChrome: Bool { UserDefaults.standard.bool(forKey: "screenshot.hideChrome") }
    /// Mostrar el mini reproductor como si sonara el libro actual (solo con `Features.audiobook`).
    static var listening: Bool { UserDefaults.standard.bool(forKey: "screenshot.listening") }
    /// Pantalla empujada: en la Biblioteca, `review` («Por revisar»), `detail` (ficha
    /// del primer libro, o del de `-screenshot.book`), `edit` (la ficha con «Escribir a mano» abierto), `candidates`
    /// («Buscar con otros datos»), `cover` («Elegir portada de internet»), `series` (la primera serie) o `shelf`
    /// (el primer estante); en el Cuaderno, `note` (la primera nota), `noteEdit` (la misma, escribiendo), `highlights` o
    /// `settings` (Ajustes); en la Mesa, `diary` (el Diario, también en la Mac) o `summary` (el resumen
    /// «Sesión terminada», como al cerrar un libro); en el lector, `contents`, `booksearch`, `marks` o `appearance` («Aa»).
    static var screen: String? { UserDefaults.standard.string(forKey: "screenshot.screen") }
    /// En la Biblioteca, el filtro ya elegido: el título de uno («Leyendo», «Por leer», «Series»…),
    /// para revisar que el conteo cuente lo que ves (`-screenshot.filter Leyendo`).
    static var filter: String? { UserDefaults.standard.string(forKey: "screenshot.filter") }
    /// Importar al arrancar los libros de `Documents/<nombre>` aunque la biblioteca ya tenga
    /// (`-screenshot.import Largos`): un libro de título larguísimo para revisar los «…».
    static var importFolder: String? { UserDefaults.standard.string(forKey: "screenshot.import") }
    /// En el diario, la parte abierta: `Mes` o `Año` (`-screenshot.part Mes`).
    static var part: String? { UserDefaults.standard.string(forKey: "screenshot.part") }
    /// Revisar animaciones en video: en el lector, `turns` pasa páginas solo
    /// (adelante, adelante, atrás) y `flow` abre «Aa» y cambia Páginas↔Continuo.
    static var demo: String? { UserDefaults.standard.string(forKey: "screenshot.demo") }
    /// Importar los libros de `Documents/Semilla` al arrancar (biblioteca vacía).
    static var seed: Bool { UserDefaults.standard.bool(forKey: "screenshot.seed") }
    /// Ajustes › Tu Gabinete como si viviera en otro lado: `icloud`, `icloudNested`,
    /// `folder` o `moving` (para revisar el dibujo en cada estado).
    static var cabinet: String? { UserDefaults.standard.string(forKey: "screenshot.cabinet") }
    /// Con `-screenshot.screen welcome`, el paso de la bienvenida: `place`, `books` o `readwise`
    /// (`-screenshot.step place`).
    static var welcomeStep: String? { UserDefaults.standard.string(forKey: "screenshot.step") }
    /// En el iPhone, girar la pantalla al arrancar: `landscape` o `portrait` (`-screenshot.turn landscape`).
    /// Con `-screenshot.turnAfter <segundos>` gira ya puesta la pantalla, para revisar que al
    /// cambiar de tamaño (girar, o abrir y cerrar el iPhone Duo) sigas en el mismo lugar.
    static var turn: String? { UserDefaults.standard.string(forKey: "screenshot.turn") }
    static var turnAfter: Double { UserDefaults.standard.double(forKey: "screenshot.turnAfter") }
    /// Solo en DEBUG: la biblioteca como si iCloud no la hubiera bajado, para revisar esas
    /// pantallas sin dejar marcadores a mano (auditoría 5): `downloading` («Bajando tu biblioteca»)
    /// o `gaveUp` (ya no la espero). `-screenshot.cloud downloading`.
    static var cloud: String? { UserDefaults.standard.string(forKey: "screenshot.cloud") }
    /// Solo en DEBUG: el estudio del iPhone Duo congela lo que cambia de una captura a otra, así
    /// cada pantalla se compara igual en los seis modos y de una ronda a otra (`-screenshot.frozen YES`):
    /// no busca datos en internet ni en las conexiones, no guarda búsquedas recientes (las de la
    /// pestaña Buscar son siempre las mismas), la sesión de muestra tiene horas fijas, y avisa
    /// (`readyMarker`) cuando el libro ya se acomodó, para no retratar «Abriendo el libro…».
    static var frozen: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "screenshot.frozen")
        #else
        false
        #endif
    }
    /// El archivo que deja el lector, en modo congelado, cuando el libro ya está en su página.
    static var readyMarker: URL { URL.documentsDirectory.appendingPathComponent(".lector-listo") }
    /// Las búsquedas recientes fijas del estudio.
    static let frozenSearches: [(text: String, count: Int)] = [("Cortázar", 3), ("Fundación", 3)]
}

/// Lo que falta decidir para el iPhone Duo (ronda 1, 27 nov 2026). Lo recomendado ya es lo que
/// ves; la otra opción de cada decisión se prueba solo en Debug, con su argumento de arranque, para
/// retratarlas lado a lado. Al decidir, la que no se eligió se borra de aquí y nada más: el resto
/// lo deciden las piezas comunes por el espacio que hay (`WindowLayout`), no estas banderas.
enum Duo {
    /// D1 · cerrado: la franja de la hora y las pestañas al costado, como la pone iOS (recomendado).
    /// D1-B, las pestañas abajo y la hora arriba, como en cualquier iPhone (`-duo.bars below`).
    static var barsBelow: Bool { chosen("duo.bars", "below") }
    /// D2 · abierto y acostado: dos páginas, una a cada lado del pliegue (recomendado). D2-B, una
    /// página con la otra de margen, como en continuo (`-duo.book page`).
    static var bookOnePage: Bool { chosen("duo.book", "page") }
    /// D2 · en continuo, el texto en la página izquierda y la derecha de margen (recomendado).
    /// D2-C2, al revés: el margen a la izquierda (`-duo.margin left`).
    static var marginOnLeft: Bool { chosen("duo.margin", "left") }
    /// D2 · abierto de pie: una página alta con renglón cómodo; el pliegue pasa por ella como en
    /// cualquier concha (recomendado). D2-F, el libro solo arriba del pliegue y las herramientas
    /// abajo, como en una mesa (`-duo.tall top`).
    static var bookAboveFold: Bool { chosen("duo.tall", "top") }
    /// D3 · abierto y acostado, lista | detalle en Biblioteca, Cuaderno y Buscar (recomendado).
    /// D3-A, una sola página que empuja la siguiente, como hoy en el iPhone (`-duo.panes one`).
    static var onePane: Bool { chosen("duo.panes", "one") }
    /// D4 · abierto y acostado, las hojas en una página con la otra a la vista (recomendado).
    /// D4-A, la hoja de iOS al centro, encima del pliegue (`-duo.tools sheet`).
    static var toolsAsSheets: Bool { chosen("duo.tools", "sheet") }
    /// D5 · pantalla baja: el pie del libro en un solo renglón (recomendado). D5-A, la tarjeta de
    /// siempre (`-duo.footer card`).
    static var footerCard: Bool { chosen("duo.footer", "card") }

    private static func chosen(_ key: String, _ value: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: key) == value
        #else
        false
        #endif
    }
}

/// Lo que todavía no funciona no se muestra: nada en la app promete algo que no hace, ni
/// siquiera en las capturas (UX-8a, 27 nov 2026: el mini reproductor y «Escuchar» salían con
/// `-screenshot.listening` y no hacían nada). Se prende aquí, en el código, cuando funcione.
enum Features {
    /// Audiolibro («Escuchar» y el mini reproductor): llega en la fase C. Apagado para todos.
    static let audiobook = false
}
