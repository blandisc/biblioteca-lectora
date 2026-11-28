import Foundation
import LectoraCore

/// Dónde vive el Gabinete: una carpeta con la biblioteca (forma de Calibre) y
/// las notas (Markdown), una al lado de la otra:
///
///     Gabinete/
///       Biblioteca/   ← la abre Calibre tal cual
///       Notas/        ← la abre Obsidian o cualquier editor
///
/// Por defecto está en el dispositivo (Archivos › En mi iPhone › Gabinete). Si
/// eliges otra carpeta (por ejemplo en iCloud Drive) se guarda un marcador
/// para volver a abrirla en cada arranque.
enum CabinetLocation {
    static let libraryFolder = "Biblioteca"
    static let notesFolder = "Notas"
    private static let bookmarkKey = "gabinete.bookmark"

    /// Carpeta del Gabinete en el dispositivo.
    static var local: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gabinete", isDirectory: true)
    }

    /// La carpeta en uso: la elegida (si sigue disponible) o la local.
    static func current() -> URL {
        resolveBookmark() ?? local
    }

    static func library(in cabinet: URL) -> URL {
        cabinet.appendingPathComponent(libraryFolder, isDirectory: true)
    }

    static func notes(in cabinet: URL) -> URL {
        cabinet.appendingPathComponent(notesFolder, isDirectory: true)
    }

    static func isLocal(_ cabinet: URL) -> Bool {
        cabinet.standardizedFileURL == local.standardizedFileURL
    }

    /// ¿Ya hay una biblioteca de Gabinete en esa carpeta? Pide permiso a la carpeta mientras
    /// mira (A5: en el iPhone, sin permiso, una carpeta de iCloud recién elegida siempre se veía
    /// vacía y se ofrecía «Mover» en vez de «Abrir»).
    static func hasLibrary(in cabinet: URL) -> Bool {
        let accessing = cabinet.startAccessingSecurityScopedResource()
        defer { if accessing { cabinet.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: library(in: cabinet).appendingPathComponent(".lectora").path)
    }

    /// «iCloud Drive › Gabinete», «En este iPhone» (o iPad, o Mac), o el nombre de la carpeta.
    static func displayName(_ cabinet: URL) -> String {
        if isLocal(cabinet) { return DeviceKind.current.here }
        let path = cabinet.standardizedFileURL.path
        if let range = path.range(of: "com~apple~CloudDocs/") {
            return "iCloud Drive › " + path[range.upperBound...].replacingOccurrences(of: "/", with: " › ")
        }
        if path.contains("Mobile Documents") { return "iCloud Drive › " + cabinet.lastPathComponent }
        return cabinet.lastPathComponent
    }

    // MARK: Marcador

    /// Recuerda la carpeta elegida. En el Mac el marcador lleva el permiso del
    /// sandbox; en el iPhone, el de la carpeta que elegiste en Archivos.
    static func remember(_ cabinet: URL) throws {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        let data = try cabinet.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static var accessing: URL?

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        startAccessing(url)
        if stale { try? remember(url) }
        return url
    }

    /// Mantiene abierto el permiso de la carpeta mientras se use.
    static func startAccessing(_ url: URL) {
        guard accessing != url else { return }
        accessing?.stopAccessingSecurityScopedResource()
        accessing = url.startAccessingSecurityScopedResource() ? url : nil
    }

    // MARK: Copias a medias (auditoría 7, M2)

    private static let stagingKey = "gabinete.copias"

    /// Anota que este aparato empieza a copiar el Gabinete a `destination` con ese token: si la
    /// app se cierra a media copia, al abrirla sé dónde quedó la carpeta de trabajo y la quito.
    static func rememberStaging(token: String, destination: URL) {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        guard let data = try? destination.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var saved = UserDefaults.standard.dictionary(forKey: stagingKey) as? [String: Data] ?? [:]
        saved[token] = data
        UserDefaults.standard.set(saved, forKey: stagingKey)
    }

    static func forgetStaging(tokens: some Sequence<String>) {
        var saved = UserDefaults.standard.dictionary(forKey: stagingKey) as? [String: Data] ?? [:]
        for token in tokens { saved[token] = nil }
        UserDefaults.standard.set(saved, forKey: stagingKey)
    }

    /// Los movimientos que este aparato empezó y no terminó: su token y a dónde copiaba.
    static func pendingStagings() -> [(token: String, destination: URL?)] {
        let saved = UserDefaults.standard.dictionary(forKey: stagingKey) as? [String: Data] ?? [:]
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        return saved.sorted { $0.key < $1.key }.map { token, data in
            var stale = false
            return (token, try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale))
        }
    }

    // MARK: Migración

    /// Lectora guardaba la biblioteca en «Biblioteca Lectora»: pasa a «Gabinete/Biblioteca».
    static func migrateLegacyFolder() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacy = documents.appendingPathComponent("Biblioteca Lectora", isDirectory: true)
        let target = library(in: local)
        let manager = FileManager.default
        guard manager.fileExists(atPath: legacy.path), !manager.fileExists(atPath: target.path) else { return }
        try? manager.createDirectory(at: local, withIntermediateDirectories: true)
        try? manager.moveItem(at: legacy, to: target)
    }
}

/// Archivos de iCloud Drive que aún no están en el dispositivo.
enum CloudFiles {
    /// Lo que se le da a iCloud para bajar los archivos chicos antes de volver a leer.
    static let settle: Duration = .seconds(3)
    /// Cada cuánto se pregunta si ya bajó un archivo.
    static let poll: Duration = .milliseconds(500)
    /// Cuántas veces (cada `settle`) se reintenta escribir lo que espera a iCloud: unos dos
    /// minutos; después, al volver a la app o al abrirla.
    static let waitAttempts = 40

    /// El archivo no está bajado: en su lugar hay un «.nombre.icloud».
    static func isPlaceholder(_ file: URL) -> Bool { CloudFile.isPlaceholder(file) }

    /// ¿Está el archivo en el dispositivo? (Fuera de iCloud, siempre.)
    static func isDownloaded(_ url: URL) -> Bool {
        // Solo su marcador de iCloud está aquí (auditoría 8, A1): no está bajado. Antes, sin archivo
        // no había valores que leer y contaba como bajado, y el lector decía «Load failed».
        if CloudFile.isPlaceholder(url) { return false }
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true else { return true }
        return values.ubiquitousItemDownloadingStatus == .current
    }

    /// Pide bajarlo y espera (hasta `timeout`) a que llegue.
    static func ensureDownloaded(_ url: URL, timeout: TimeInterval = 120) async -> Bool {
        if isDownloaded(url) { return true }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: CloudFiles.poll)
            if isDownloaded(url) { return true }
        }
        return isDownloaded(url)
    }

    /// Pide bajar (sin esperar) los archivos pequeños que la app necesita a
    /// mano: registros del catálogo, portadas, metadata.opf y notas. Los libros
    /// se bajan al abrirlos.
    static func requestSmallFiles(in folder: URL) {
        let manager = FileManager.default
        guard let walker = manager.enumerator(at: folder, includingPropertiesForKeys: [.isUbiquitousItemKey],
                                              options: []) else { return }
        for case let url as URL in walker {
            var name = url.lastPathComponent
            // Un archivo que no está en el dispositivo aparece como «.nombre.icloud».
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
            }
            let small = name.hasSuffix(".jsonl") || name.hasSuffix(".json") || name == "cover.jpg" || name == "metadata.opf"
                || name.hasSuffix(".md")
            guard small else { continue }
            let real = url.deletingLastPathComponent().appendingPathComponent(name)
            if !isDownloaded(real) { try? manager.startDownloadingUbiquitousItem(at: real) }
        }
    }
}

extension ChangeLogError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ownLogNotDownloaded:
            "Tu biblioteca todavía se está bajando de iCloud. Espera un momento y vuelve a intentarlo."
        }
    }
}

extension NoteFolderError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notDownloaded:
            "Esta nota todavía se está bajando de iCloud. Espera un momento y vuelve a intentarlo."
        }
    }
}
