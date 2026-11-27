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
    /// Mostrar el mini reproductor como si sonara el libro actual.
    static var listening: Bool { UserDefaults.standard.bool(forKey: "screenshot.listening") }
    /// Pantalla empujada: en la Biblioteca, `review` («Por revisar»), `detail` (ficha
    /// del primer libro, o del de `-screenshot.book`), `edit` (la ficha con «Escribir a mano» abierto) o `shelf` (el primer estante); en el Cuaderno, `note` (la primera nota), `highlights` o
    /// `settings` (Ajustes); en el lector, `contents`, `booksearch`, `marks` o `appearance` («Aa»).
    static var screen: String? { UserDefaults.standard.string(forKey: "screenshot.screen") }
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

/// Lo que todavía no funciona no se muestra: nada en la app promete algo que no hace.
enum Features {
    /// Audiolibro (Escuchar, Guiada, mini reproductor): llega en la fase C.
    /// Las capturas lo enseñan para revisar su diseño.
    static var audiobook: Bool { LaunchOptions.listening }
}
