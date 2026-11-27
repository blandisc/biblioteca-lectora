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
    /// del primer libro, o del de `-screenshot.book`), `edit` (la ficha con «Escribir a mano» abierto) o `shelf` (el primer estante); en el Cuaderno, `note` (la primera nota), `highlights` o
    /// `settings` (Ajustes); en la Mesa, `diary` (el Diario, también en la Mac); en el lector, `contents`, `booksearch`, `marks` o `appearance` («Aa»).
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
}

/// Lo que todavía no funciona no se muestra: nada en la app promete algo que no hace, ni
/// siquiera en las capturas (UX-8a, 27 nov 2026: el mini reproductor y «Escuchar» salían con
/// `-screenshot.listening` y no hacían nada). Se prende aquí, en el código, cuando funcione.
enum Features {
    /// Audiolibro («Escuchar» y el mini reproductor): llega en la fase C. Apagado para todos.
    static let audiobook = false
}
