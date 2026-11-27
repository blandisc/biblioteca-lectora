import CryptoKit
import Foundation
import LectoraCore
import PDFKit
import UniformTypeIdentifiers

/// La biblioteca: una carpeta con la misma forma que una de Calibre
/// (`Autor/Título (id)/archivo + cover.jpg + metadata.opf`) y un catálogo en el
/// registro de cambios de LectoraCore (`.lectora/registro/`). Si mañana quieres
/// volver a Calibre, abres la carpeta en Calibre y restauras la base de datos.
@MainActor
final class LibraryStore: ObservableObject {
    enum ImportOutcome {
        case added(Book)
        case duplicate(Book)
    }

    enum LibraryError: LocalizedError {
        case bookNotFound
        case folderTaken
        case coverUnavailable
        /// RB-4: el archivo no es un libro que se pueda abrir (vacío, roto o de otro tipo).
        case unreadable(name: String, reason: String)
        var errorDescription: String? {
            switch self {
            case .unreadable(let name, let reason): "«\(name)» no entró a tu biblioteca. \(reason)"
            case .bookNotFound: "No encontré ese libro en la biblioteca."
            case .folderTaken: "Ya hay otro libro con ese título y autor en la carpeta."
            case .coverUnavailable: "No pude bajar esa portada. Prueba con otra."
            }
        }
    }

    static let shared = LibraryStore()

    static let importableTypes: [UTType] = [
        UTType(filenameExtension: "epub"),
        .pdf,
        UTType(filenameExtension: "mobi"),
        UTType(filenameExtension: "azw3"),
        UTType(filenameExtension: "fb2"),
        UTType(filenameExtension: "cbz"),
    ].compactMap { $0 }

    @Published private(set) var books: [Book] = [] {
        // Lo que se calcula sobre toda la biblioteca se recalcula solo cuando cambian los libros (RB, A8).
        didSet { duplicatesCache = nil; incompleteCache = nil }
    }
    private var duplicatesCache: [[Book]]?
    private var incompleteCache: [UUID]?
    /// «Por revisar»: libros con datos dudosos y sus candidatos de internet.
    @Published private(set) var reviews: [UUID: [MetadataCandidate]] = [:]
    /// Libros que se están buscando en internet ahora mismo.
    @Published private(set) var identifying: Set<UUID> = []
    /// Libros que no se pudieron buscar en internet (sin conexión); se reintentan.
    @Published private(set) var pendingLookup: Set<UUID> = []
    /// Lo que se completó solo desde internet, para revisarlo y deshacerlo.
    @Published private(set) var filled: [UUID: FilledRecord] = [:]
    /// Reglas de autores y etiquetas (en la carpeta: viajan con la biblioteca).
    @Published private(set) var rules = MetadataRules()
    /// Estantes: búsquedas guardadas con nombre (CB-1). En la carpeta: viajan con la biblioteca.
    @Published private(set) var shelves: [SavedShelf] = []
    /// Buscar datos de muchos libros a la vez (CB-4): cómo va. Sigue aunque cierres la ventana.
    @Published private(set) var batch: BatchLookup.Progress?
    /// Parejas que dijiste que no son el mismo libro (CB-3).
    @Published private(set) var notDuplicates: Set<DuplicateFinder.Pair> = [] {
        didSet { duplicatesCache = nil }
    }
    private var batchTask: Task<Void, Never>?
    private var batchToken: UUID?
    /// Libro que se quedó → los que se juntaron en él (RB-3: sus subrayados lo siguen).
    private var mergedInto: [UUID: [UUID]] = [:]
    /// Avance de una importación en curso.
    @Published private(set) var progress: (done: Int, total: Int)?

    /// «Añadiendo 3 de 32…» mientras se importa; la misma frase en la Biblioteca y la bienvenida.
    var progressLine: String? {
        progress.map { "Añadiendo \(min($0.done + 1, $0.total)) de \($0.total)…" }
    }

    /// Lo hecho de la importación en curso, de 0 a 1.
    var progressFraction: Double? {
        progress.map { $0.total > 0 ? Double($0.done) / Double($0.total) : 0 }
    }

    /// Carpeta de la biblioteca (`Gabinete/Biblioteca`): cambia si eliges otra.
    @Published private(set) var root: URL
    /// Moviendo la biblioteca a otra carpeta.
    @Published private(set) var moving = false
    private var log: ChangeLog
    private let clock: HybridLogicalClock
    private var state = LibraryState()
    private lazy var extractor = MetadataExtractor()
    /// Importaciones en fila: una termina antes de que empiece la siguiente.
    private var lastImport: Task<[Result<ImportOutcome, Error>], Never>?

    init(root: URL = LibraryStore.defaultRoot) {
        self.root = root
        try? FileManager.default.createDirectory(at: root.deletingLastPathComponent()
            .appendingPathComponent(CabinetLocation.notesFolder), withIntermediateDirectories: true)
        let device = AnnotationStore.deviceID
        log = ChangeLog(directory: root.appendingPathComponent(".lectora/registro", isDirectory: true), deviceID: device)
        clock = HybridLogicalClock(node: device)
        reload()
    }

    /// La biblioteca del Gabinete en uso: la carpeta que elegiste (p. ej. en
    /// iCloud Drive) o «En mi iPhone › Gabinete › Biblioteca» en Archivos.
    nonisolated static var defaultRoot: URL {
        CabinetLocation.migrateLegacyFolder()
        return CabinetLocation.library(in: CabinetLocation.current())
    }

    /// Carpeta del Gabinete (la biblioteca y las notas viven dentro).
    var cabinet: URL { root.deletingLastPathComponent() }
    var isLocal: Bool { CabinetLocation.isLocal(cabinet) }

    // MARK: Dónde vive el Gabinete (B3)

    enum LocationError: LocalizedError {
        case alreadyHasLibrary
        case incomplete(copied: Int, expected: Int)
        /// Ya hay una carpeta Biblioteca o Notas ahí: nunca se borra lo que no es tuyo de Gabinete.
        case occupied(String)
        /// Moverlo dentro de sí mismo (o al revés) lo copiaría sin fin.
        case insideItself
        var errorDescription: String? {
            switch self {
            case .occupied(let folder):
                "Esa carpeta ya tiene una carpeta «\(folder)». Para no tocarla, elige otra carpeta o crea una nueva para tu Gabinete."
            case .insideItself:
                "No se puede mover el Gabinete dentro de sí mismo. Elige una carpeta que esté fuera de él."
            case .alreadyHasLibrary:
                "Esa carpeta ya tiene una biblioteca de Gabinete. Ábrela en vez de mover la tuya encima."
            case .incomplete(let copied, let expected):
                "Solo se copiaron \(copied) de \(expected) elementos. Tu biblioteca sigue donde estaba."
            }
        }
    }

    /// Lleva la biblioteca (y las notas) a otra carpeta y la usa desde ahí. Se
    /// copia todo, se comprueba y solo entonces se borra la copia local.
    func move(toCabinet destination: URL) async throws {
        CabinetLocation.startAccessing(destination)
        guard !CabinetLocation.hasLibrary(in: destination) else { throw LocationError.alreadyHasLibrary }
        try Self.checkMove(from: cabinet, to: destination)
        // Lo que se escribiera a medio camino se quedaría en la copia vieja.
        stopBatch()
        _ = await lastImport?.value
        moving = true
        defer { moving = false }
        let source = cabinet
        let wasLocal = isLocal
        let (copiedCount, expectedCount) = try await Task.detached(priority: .userInitiated) { () -> (Int, Int) in
            let manager = FileManager.default
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            var expected = 0, copied = 0
            for folder in [CabinetLocation.libraryFolder, CabinetLocation.notesFolder] {
                let from = source.appendingPathComponent(folder), to = destination.appendingPathComponent(folder)
                guard manager.fileExists(atPath: from.path) else { continue }
                expected += LibraryStore.countItems(in: from)
                try LibraryStore.coordinatedCopy(from: from, to: to)
                copied += LibraryStore.countItems(in: to)
            }
            return (copied, expected)
        }.value
        guard copiedCount >= expectedCount else { throw LocationError.incomplete(copied: copiedCount, expected: expectedCount) }
        try CabinetLocation.remember(destination)
        open(cabinet: destination)
        if wasLocal {
            for folder in [CabinetLocation.libraryFolder, CabinetLocation.notesFolder] {
                try? FileManager.default.removeItem(at: source.appendingPathComponent(folder))
            }
        }
    }

    /// Usa la biblioteca que ya está en esa carpeta (p. ej. la que creó tu Mac).
    func use(cabinet destination: URL) throws {
        CabinetLocation.startAccessing(destination)
        try CabinetLocation.remember(destination)
        open(cabinet: destination)
    }

    /// Vuelve a la carpeta del dispositivo (no copia nada).
    func useLocalCabinet() {
        CabinetLocation.forget()
        open(cabinet: CabinetLocation.local)
    }

    private func open(cabinet: URL) {
        root = CabinetLocation.library(in: cabinet)
        try? FileManager.default.createDirectory(at: CabinetLocation.notes(in: cabinet), withIntermediateDirectories: true)
        log = ChangeLog(directory: root.appendingPathComponent(".lectora/registro", isDirectory: true), deviceID: AnnotationStore.deviceID)
        // Otra biblioteca: lo de la anterior no se queda aunque la nueva esté vacía.
        state = LibraryState()
        books = []
        reviews = [:]
        pendingLookup = []
        filled = [:]
        rules = MetadataRules()
        reload()
        refreshFromCloud()
    }

    /// Trae lo que cambió en otros dispositivos: pide a iCloud los registros,
    /// portadas y metadatos que falten y vuelve a leer el catálogo.
    func refreshFromCloud() {
        let folder = root, log = log
        Task.detached(priority: .utility) { [weak self] in
            CloudFiles.requestSmallFiles(in: folder)
            try? await Task.sleep(for: CloudFiles.settle)
            // El registro se lee fuera del hilo de la interfaz: con años de lectura pesa (RB, A7).
            let changes = (try? log.readAll())?.changes
            await self?.reload(with: changes, ifStillAt: folder)
        }
    }

    private func reload(with changes: [Change]?, ifStillAt folder: URL) {
        guard root == folder else { return }
        apply(changes)
    }

    /// El archivo del libro, bajado de iCloud si hacía falta.
    func downloadedFile(for book: Book) async -> URL? {
        guard let url = fileURL(for: book) else { return nil }
        return await CloudFiles.ensureDownloaded(url) ? url : nil
    }

    /// RB-2: no se mueve encima de carpetas que ya existen ni dentro de sí mismo.
    nonisolated static func checkMove(from source: URL, to destination: URL) throws {
        switch FolderMove.problem(from: source, to: destination,
                                  folders: [CabinetLocation.libraryFolder, CabinetLocation.notesFolder]) {
        case .insideItself: throw LocationError.insideItself
        case .occupied(let folder): throw LocationError.occupied(folder)
        case nil: break
        }
    }

    nonisolated static func countItems(in folder: URL) -> Int {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var count = 0
        while walker?.nextObject() != nil { count += 1 }
        return count
    }

    /// Copia con NSFileCoordinator: iCloud sabe que se está escribiendo. Nunca
    /// reemplaza: si el destino ya existe, falla sin tocarlo.
    nonisolated static func coordinatedCopy(from source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], writingItemAt: destination,
                                       options: [], error: &coordinationError) { from, to in
            do {
                try FileManager.default.copyItem(at: from, to: to)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
    }

    func reload() {
        apply((try? log.readAll())?.changes)
    }

    private func apply(_ changes: [Change]?) {
        var fresh = LibraryState()
        if let changes { fresh.apply(changes) }
        // Si el registro no se pudo leer (iCloud sin bajar, sin red), la biblioteca no se
        // vacía: se queda lo que había (RB-3).
        if fresh.allIDs(of: .book).isEmpty, !books.isEmpty { return }
        if let latest = fresh.latest { clock.receive(latest) }
        state = fresh
        books = fresh.books()
        rebuildMergedInto()
        // Estantes, reglas y «Por revisar» también pudieron cambiar en otro dispositivo.
        loadReviews()
    }

    func book(id: UUID) -> Book? { books.first { $0.id == id } }

    private func rebuildMergedInto() {
        var table: [UUID: [UUID]] = [:]
        for id in state.allIDs(of: .book) {
            if let target = state.fields(of: .book, id: id)?[Self.mergedIntoField]?.stringValue.flatMap(UUID.init(uuidString:)) {
                table[target, default: []].append(id)
            }
        }
        mergedInto = table
    }

    func fileURL(for book: Book) -> URL? {
        book.filePath.map { root.appendingPathComponent($0) }
    }

    func coverURL(for book: Book) -> URL? {
        guard let folder = book.folderPath else { return nil }
        let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.coverFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: Importar

    @discardableResult
    func importFiles(_ urls: [URL]) async -> [Result<ImportOutcome, Error>] {
        let previous = lastImport
        let task = Task { @MainActor in
            _ = await previous?.value
            return await self.runImport(urls)
        }
        lastImport = task
        return await task.value
    }

    private func runImport(_ urls: [URL]) async -> [Result<ImportOutcome, Error>] {
        progress = (0, urls.count)
        defer { progress = nil }
        var results: [Result<ImportOutcome, Error>] = []
        var added: [Book] = []
        for (index, url) in urls.enumerated() {
            do {
                let outcome = try await importFile(url)
                if case .added(let book) = outcome { added.append(book) }
                results.append(.success(outcome))
            } catch {
                results.append(.failure(error))
            }
            progress = (index + 1, urls.count)
        }
        // Después de importar, se buscan en internet sin detener la fila.
        Task { [added] in
            for book in added { await self.identify(book.id) }
        }
        return results
    }

    /// Lee el archivo, evita duplicados, limpia los datos y lo guarda ordenado.
    func importFile(_ source: URL) async throws -> ImportOutcome {
        // Copia y huella fuera del hilo de la interfaz: un PDF de 300 MB no congela la app.
        let (staging, hash) = try await Task.detached(priority: .userInitiated) {
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(source.pathExtension.lowercased())
            try FileManager.default.copyItem(at: source, to: staging)
            return (staging, try LibraryStore.sha256(of: staging))
        }.value
        defer { try? FileManager.default.removeItem(at: staging) }

        if let problem = Self.problem(with: staging) {
            throw LibraryError.unreadable(name: source.lastPathComponent, reason: problem)
        }
        if let existing = books.first(where: { $0.fileHash == hash }) { return .duplicate(existing) }

        let extracted = (try? await extractor.extract(from: staging)) ?? ExtractedMetadata()
        var book = MetadataCleaner.clean(Book(
            title: extracted.title ?? "",
            authors: extracted.authors,
            series: extracted.series,
            seriesIndex: extracted.seriesIndex,
            tags: extracted.tags,
            language: extracted.language,
            identifiers: extracted.isbn.map { ["isbn": $0] } ?? [:],
            publisher: extracted.publisher,
            published: extracted.published,
            summary: extracted.summary
        ), fileName: source.lastPathComponent)
        book = rules.apply(to: book)
        // Mismo ISBN y mismo formato: es el mismo libro. (Un PDF y un EPUB de la
        // misma edición sí entran; luego se podrán unir como formatos de un libro.)
        let format = source.pathExtension.lowercased()
        if let isbn = book.identifiers["isbn"].flatMap(ISBN.normalized), let existing = books.first(where: {
            $0.identifiers["isbn"].flatMap(ISBN.normalized) == isbn && $0.formats.contains(format.uppercased())
        }) {
            return .duplicate(existing)
        }

        // Número de Calibre libre, también en disco (otro dispositivo pudo usarlo).
        var calibreID = (books.compactMap(\.calibreID).max() ?? 0) + 1
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(
            CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)).path) {
            calibreID += 1
        }
        book.calibreID = calibreID
        book.fileHash = hash
        book.addedAt = Date()

        let folder = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
        let fileName = CalibreLayout.fileName(title: book.title, authors: book.authors, fileExtension: format)
        let folderURL = root.appendingPathComponent(folder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: staging, to: folderURL.appendingPathComponent(fileName))
            book.filePath = "\(folder)/\(fileName)"

            var hasCover = false
            if let cover = extracted.cover.flatMap({ CoverImaging.jpeg(from: $0) }) {
                try cover.write(to: folderURL.appendingPathComponent(CalibreLayout.coverFileName), options: .atomic)
                hasCover = true
            }
            try writeOPF(book, hasCover: hasCover)
            try record(book)
            return .added(book)
        } catch {
            // Nada a medias: si algo falla, la carpeta del libro no se queda.
            try? FileManager.default.removeItem(at: folderURL)
            removeIfEmpty(folderURL.deletingLastPathComponent())
            throw error
        }
    }

    /// RB-4: solo entran archivos que se pueden abrir. Revisa la firma del archivo y, en
    /// un PDF, que tenga páginas.
    nonisolated static func problem(with file: URL) -> String? {
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let header = (try? FileHandle(forReadingFrom: file)).flatMap { handle in
            defer { try? handle.close() }
            return try? handle.read(upToCount: 4096)
        } ?? Data()
        if let problem = BookFileCheck.problem(fileExtension: file.pathExtension, header: header, size: size) {
            return problem
        }
        if file.pathExtension.lowercased() == "pdf", (PDFDocument(url: file)?.pageCount ?? 0) == 0 {
            return "No es un PDF que se pueda abrir."
        }
        return nil
    }

    // MARK: Editar

    /// Guarda la edición manual. Si cambian el título o el primer autor, la
    /// carpeta y el archivo se renombran como lo haría Calibre.
    @discardableResult
    func update(_ edited: Book, cover newCover: Data? = nil) throws -> Book {
        guard let original = book(id: edited.id) else { throw LibraryError.bookNotFound }
        var book = MetadataCleaner.clean(edited, manual: true)
        // Los otros formatos se buscan con el nombre que tienen hoy en el disco, no con el de
        // una copia vieja (deshacer un cambio de autor los dejaba huérfanos, RB-5).
        let onDisk = Dictionary(original.extraFiles.map { (($0 as NSString).pathExtension.lowercased(), $0) },
                                uniquingKeysWith: { first, _ in first })
        book.extraFiles = book.extraFiles.map { onDisk[($0 as NSString).pathExtension.lowercased()] ?? $0 }

        // Si el título o el autor cambiaron, o la carpeta no tiene la forma de Calibre, se recoloca.
        if let oldPath = original.filePath, let calibreID = book.calibreID,
           oldPath != expectedPath(for: book, calibreID: calibreID, fileExtension: (oldPath as NSString).pathExtension) {
            let oldFolder = root.appendingPathComponent((oldPath as NSString).deletingLastPathComponent, isDirectory: true)
            let newFolderPath = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
            let newFolder = root.appendingPathComponent(newFolderPath, isDirectory: true)
            var newName = CalibreLayout.fileName(title: book.title, authors: book.authors,
                                                 fileExtension: (oldPath as NSString).pathExtension)
            let movesFolder = newFolder.standardizedFileURL != oldFolder.standardizedFileURL
            // Solo cambian mayúsculas: para el disco (APFS, iCloud) es la misma carpeta.
            let caseOnly = movesFolder && FolderMove.sameIgnoringCase(newFolder, oldFolder)
            if caseOnly {
                try FolderMove.move(oldFolder.deletingLastPathComponent(), to: newFolder.deletingLastPathComponent())
                try FolderMove.move(newFolder.deletingLastPathComponent().appendingPathComponent(oldFolder.lastPathComponent), to: newFolder)
            } else if movesFolder {
                guard !FileManager.default.fileExists(atPath: newFolder.path) else { throw LibraryError.folderTaken }
                try FileManager.default.createDirectory(at: newFolder.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: oldFolder, to: newFolder)
            }
            let oldFile = newFolder.appendingPathComponent((oldPath as NSString).lastPathComponent)
            // Un libro que sigue en iCloud sin bajar no se renombra: se queda con su nombre y «Ordenar» lo arregla luego.
            if CloudFiles.isPlaceholder(oldFile) { newName = oldFile.lastPathComponent }
            let newFile = newFolder.appendingPathComponent(newName)
            do {
                try FolderMove.move(oldFile, to: newFile)
            } catch {
                // Deshacer el cambio de carpeta: el libro sigue donde estaba.
                if movesFolder { try? FolderMove.move(newFolder, to: oldFolder) }
                throw error
            }
            if movesFolder && !caseOnly {
                removeIfEmpty(oldFolder.deletingLastPathComponent())
                CoverImaging.forget(oldFolder.appendingPathComponent(CalibreLayout.coverFileName))
            }
            book.filePath = "\(newFolderPath)/\(newName)"
            // Los otros formatos (CB-3) se llaman igual que el principal, con su extensión.
            book.extraFiles = book.extraFiles.map { extra in
                let wanted = CalibreLayout.fileName(title: book.title, authors: book.authors,
                                                    fileExtension: (extra as NSString).pathExtension)
                let from = newFolder.appendingPathComponent(extra), to = newFolder.appendingPathComponent(wanted)
                guard wanted != extra, FolderMove.sameIgnoringCase(from, to) || !FileManager.default.fileExists(atPath: to.path),
                      !CloudFiles.isPlaceholder(from), (try? FolderMove.move(from, to: to)) != nil
                else { return extra }
                return wanted
            }
        }

        if let newCover, let jpeg = CoverImaging.jpeg(from: newCover), let folder = book.folderPath {
            let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.coverFileName)
            try jpeg.write(to: url, options: .atomic)
            CoverImaging.forget(url)
        }
        try writeOPF(book, hasCover: coverURL(for: book) != nil)
        try record(book)
        return book
    }

    // MARK: Ordenar (B3)

    struct TidyReport {
        var relocated = 0
        var checked = 0
        /// Libros del catálogo cuyo archivo ya no está.
        var missing: [String] = []
        /// Carpetas con libros que no están en el catálogo (p. ej. copiadas a mano).
        var strays: [String] = []
    }

    /// Ordena la carpeta como lo haría Calibre: cada libro en `Autor/Título (id)`
    /// con su archivo, portada y metadata.opf al día. Avisa de lo que falta y
    /// de lo que sobra, sin borrar nada.
    func tidy() -> TidyReport {
        var report = TidyReport()
        let manager = FileManager.default
        for book in books {
            guard let path = book.filePath, let calibreID = book.calibreID else { continue }
            report.checked += 1
            let file = root.appendingPathComponent(path)
            let placeholder = file.deletingLastPathComponent().appendingPathComponent(".\(file.lastPathComponent).icloud")
            guard manager.fileExists(atPath: file.path) || manager.fileExists(atPath: placeholder.path) else {
                report.missing.append(book.title)
                continue
            }
            let relocates = path != expectedPath(for: book, calibreID: calibreID, fileExtension: file.pathExtension)
            if (try? update(book)) != nil, relocates { report.relocated += 1 }
        }
        let known = Set(books.compactMap(\.folderPath))
        let authors = (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for author in authors where !author.lastPathComponent.hasPrefix(".") && author.hasDirectoryPath {
            let titles = (try? manager.contentsOfDirectory(at: author, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for title in titles where title.hasDirectoryPath {
                let relative = "\(author.lastPathComponent)/\(title.lastPathComponent)"
                if !known.contains(relative) { report.strays.append(relative) }
            }
        }
        return report
    }

    private func expectedPath(for book: Book, calibreID: Int, fileExtension: String) -> String {
        CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID) + "/"
            + CalibreLayout.fileName(title: book.title, authors: book.authors, fileExtension: fileExtension)
    }

    // MARK: Buscar en internet

    /// Búsqueda en Open Library (y en Google Books si diste una clave en Ajustes).
    private var service: MetadataService {
        MetadataService(googleKey: UserDefaults.standard.string(forKey: MetadataKeys.googleKey))
    }

    /// Busca el libro en internet. Si es claramente el mismo libro, completa lo
    /// que falta (y la portada); si hay dudas, lo deja en «Por revisar». Sin
    /// internet no lo manda a revisar: queda pendiente y se vuelve a intentar.
    /// Con `askAlways` (desde la ficha) siempre deja los candidatos para elegir.
    @discardableResult
    func identify(_ bookID: UUID, askAlways: Bool = false) async -> MetadataService.Decision? {
        guard let book = book(id: bookID), !identifying.contains(bookID) else { return nil }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }

        let result = await service.lookup(book)
        if result.decision == .unreachable {
            setPending(bookID, true)
            return .unreachable
        }
        setPending(bookID, false)
        if result.decision == .apply, !askAlways, let best = result.candidates.first {
            var cover: Data?
            if coverURL(for: book) == nil { cover = await service.cover(for: best, language: book.language, title: book.title) }
            // Pudo cambiar mientras se buscaba (lo editaste): se completa lo más reciente.
            let current = self.book(id: bookID) ?? book
            let completed = rules.apply(to: MetadataMatcher.fillMissing(current, from: best))
            if (try? update(completed, cover: cover)) != nil {
                recordFilled(before: current, after: completed, addedCover: cover != nil)
            }
            setReview(bookID, candidates: nil)
        } else {
            setReview(bookID, candidates: result.candidates)
        }
        return result.decision
    }

    /// «Buscar con otros datos»: otro título, autor o ISBN. Los candidatos
    /// reemplazan a los de «Por revisar» de ese libro.
    @discardableResult
    func search(title: String, author: String?, isbn: String?, for bookID: UUID) async -> MetadataService.Decision? {
        guard let book = book(id: bookID), !identifying.contains(bookID) else { return nil }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }
        let result = await service.search(title: title, author: author, isbn: isbn, for: book)
        if result.decision != .unreachable { setReview(bookID, candidates: result.candidates) }
        return result.decision
    }

    /// Completa un candidato con su sinopsis (para la vista previa).
    func details(for candidate: MetadataCandidate, bookID: UUID) async -> MetadataCandidate {
        guard let book = book(id: bookID) else { return candidate }
        let detailed = await service.withSummary(candidate, for: book)
        if detailed.summary != candidate.summary, var list = reviews[bookID],
           let index = list.firstIndex(where: { $0.id == candidate.id }) {
            list[index] = detailed
            setReview(bookID, candidates: list)
        }
        return detailed
    }

    /// Qué portada usar al aplicar un candidato.
    enum CoverPick: Hashable {
        /// La que tiene el libro.
        case keep
        /// La mejor que encuentre Lectora.
        case automatic
        /// La que elegiste en la cuadrícula.
        case url(URL)
    }

    /// Elegiste un candidato: sus datos (y la portada que elijas) reemplazan a los del libro.
    func apply(_ candidate: MetadataCandidate, to bookID: UUID, cover pick: CoverPick = .automatic) async throws {
        guard let book = book(id: bookID) else { throw LibraryError.bookNotFound }
        let detailed = await service.withSummary(candidate, for: book)
        let cover: Data?
        switch pick {
        case .keep: cover = nil
        case .automatic: cover = await service.cover(for: detailed, language: book.language)
        case .url(let url): cover = await service.coverData(at: url)
        }
        let current = self.book(id: bookID) ?? book
        try update(rules.apply(to: MetadataMatcher.replace(current, with: detailed)), cover: cover)
        setReview(bookID, candidates: nil)
        forgetFilled(bookID)
    }

    // MARK: Portadas para elegir

    /// Portadas de internet para un candidato (las de sus ediciones primero).
    func coverOptions(for candidate: MetadataCandidate, bookID: UUID) async -> [URL] {
        let book = book(id: bookID)
        return await service.coverOptions(for: candidate, language: book?.language, title: candidate.title, limit: 8)
    }

    /// Portadas de internet para un libro: las de su obra si ya se conoce
    /// (openlibrary: en el catálogo), si no, las de lo que encuentre la búsqueda.
    func coverOptions(for bookID: UUID) async -> [URL] {
        guard let book = book(id: bookID) else { return [] }
        var candidates: [MetadataCandidate] = []
        if let work = book.identifiers["openlibrary"] {
            candidates = [MetadataCandidate(id: "ol:/works/\(work)", source: .openLibrary, title: book.title,
                                            workKey: "/works/\(work)")]
        } else {
            candidates = Array(await service.lookup(book).candidates.prefix(Theme.Lists.coverSources))
        }
        var urls: [URL] = []
        for candidate in candidates {
            let options = await service.coverOptions(for: candidate, language: book.language, title: book.title, limit: 8)
            for url in options where !urls.contains(url) { urls.append(url) }
        }
        return Array(urls.prefix(Theme.Lists.coverOptions))
    }

    /// Cambia la portada por la elegida en la cuadrícula.
    func setCover(_ url: URL, for bookID: UUID) async throws {
        guard let data = await service.coverData(at: url) else { throw LibraryError.coverUnavailable }
        guard let book = book(id: bookID) else { throw LibraryError.bookNotFound }
        try update(book, cover: data)
    }

    // MARK: Reglas

    func saveRules(_ new: MetadataRules) {
        let before = Self.ruleTable(rules), after = Self.ruleTable(new)
        let changed = Set(before.keys).union(after.keys).filter { before[$0] != after[$0] }
        rules = Self.rules(from: persist(after, keys: changed, to: rulesURL,
                                         read: { (try? JSONDecoder().decode(MetadataRules.self, from: $0)).map(Self.ruleTable) },
                                         write: { try? JSONEncoder().encode(Self.rules(from: $0)) }))
    }

    /// Cada regla con su clave, para guardar solo las que cambiaron.
    private static func ruleTable(_ rules: MetadataRules) -> [String: MetadataRules.Rule] {
        var table: [String: MetadataRules.Rule] = [:]
        for rule in rules.authors { table["autor:\(rule.id)"] = rule }
        for rule in rules.tags { table["etiqueta:\(rule.id)"] = rule }
        return table
    }

    private static func rules(from table: [String: MetadataRules.Rule]) -> MetadataRules {
        let sorted = { (prefix: String) in
            table.filter { $0.key.hasPrefix(prefix) }.values.sorted { $0.from.localizedStandardCompare($1.from) == .orderedAscending }
        }
        return MetadataRules(authors: sorted("autor:"), tags: sorted("etiqueta:"))
    }

    /// Aplica las reglas a toda la biblioteca. Devuelve cuántos libros cambiaron.
    @discardableResult
    func applyRulesToLibrary() -> Int {
        var changed = 0
        for book in books {
            let mapped = rules.apply(to: book)
            if mapped != book, (try? update(mapped)) != nil { changed += 1 }
        }
        return changed
    }

    // MARK: Estantes (CB-1)

    /// Guarda un estante nuevo o los cambios de uno que ya existe.
    func saveShelf(_ shelf: SavedShelf) {
        var table = Dictionary(shelves.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        table[shelf.id] = shelf
        persistShelves(table, changed: shelf.id)
    }

    func removeShelf(id: UUID) {
        var table = Dictionary(shelves.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        table[id] = nil
        persistShelves(table, changed: id)
    }

    private func persistShelves(_ table: [UUID: SavedShelf], changed: UUID) {
        shelves = Self.ordered(persist(table, keys: [changed], to: shelvesURL,
                                       read: { (try? JSONDecoder().decode([SavedShelf].self, from: $0)).map(Self.shelfTable) },
                                       write: { try? JSONEncoder().encode(Self.ordered($0)) }))
    }

    private static func shelfTable(_ list: [SavedShelf]) -> [UUID: SavedShelf] {
        Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
    }

    private static func ordered(_ table: [UUID: SavedShelf]) -> [SavedShelf] {
        table.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func shelf(id: UUID) -> SavedShelf? { shelves.first { $0.id == id } }

    // MARK: Ordenar autores, series y etiquetas (CB-2)

    /// Lo que cambió una operación de la biblioteca entera, para deshacerla.
    struct CatalogChange {
        var originals: [Book] = []
        var rulesBefore: MetadataRules
        var failed: [String] = []
    }

    /// Renombra o fusiona un autor, una serie o una etiqueta en todos sus libros. Con autores y
    /// etiquetas, también deja la regla para lo que llegue después (los libros que importes).
    @discardableResult
    func rename(_ rename: CatalogRename) -> CatalogChange {
        var change = CatalogChange(rulesBefore: rules)
        for book in books where rename.touches(book) {
            do {
                try update(rename.apply(to: book))
                change.originals.append(book)
            } catch {
                change.failed.append(book.title)
            }
        }
        let fresh = rename.from.filter { CatalogRename.key($0) != CatalogRename.key(rename.to) }
        var learned = rules
        switch rename.field {
        case .author:
            for value in fresh where !learned.authors.contains(where: { CatalogRename.key($0.from) == CatalogRename.key(value) }) {
                learned.authors.append(.init(from: value, to: rename.to))
            }
        case .tag:
            for value in fresh where !learned.tags.contains(where: { CatalogRename.key($0.from) == CatalogRename.key(value) }) {
                learned.tags.append(.init(from: value, to: rename.to))
            }
        case .series: break
        }
        if learned != rules { saveRules(learned) }
        return change
    }

    /// Los tomos de una serie como 1, 2, 3… en el orden que ya tenían.
    @discardableResult
    func renumber(series: String) -> CatalogChange {
        var change = CatalogChange(rulesBefore: rules)
        let tomes = books.filter { $0.series == series }
        for renumbered in CatalogRename.renumber(tomes) {
            guard let original = book(id: renumbered.id) else { continue }
            do {
                try update(renumbered)
                change.originals.append(original)
            } catch {
                change.failed.append(original.title)
            }
        }
        return change
    }

    /// Deshace un `rename` o `renumber`: los libros como estaban y las reglas de antes.
    func restore(_ change: CatalogChange) {
        for original in change.originals { _ = try? update(original) }
        if change.rulesBefore != rules { saveRules(change.rulesBefore) }
    }

    // MARK: Lo que se completó solo

    private func recordFilled(before: Book, after: Book, addedCover: Bool) {
        var changes = FilledField.allCases.compactMap { field -> FilledChange? in
            guard field != .cover else { return nil }
            let old = field.value(in: before), new = field.value(in: after)
            return old == new ? nil : FilledChange(field: field, old: old, new: new)
        }
        if addedCover { changes.append(FilledChange(field: .cover, old: nil, new: "Nueva")) }
        guard !changes.isEmpty else { return }
        filled[before.id] = FilledRecord(date: Date(), changes: changes)
        persistFilled([before.id])
    }

    /// Deshace un dato que se completó solo. Si lo cambiaste después, se respeta lo tuyo.
    func undoFilled(_ field: FilledField, for bookID: UUID) throws {
        guard var record = filled[bookID], let change = record.changes.first(where: { $0.field == field }),
              var book = book(id: bookID) else { return }
        if field == .cover {
            if let url = coverURL(for: book) {
                try FileManager.default.removeItem(at: url)
                CoverImaging.forget(url)
            }
            try update(book)
        } else if field.value(in: book) == change.new {
            field.restore(change.old, in: &book)
            try update(book)
        }
        record.changes.removeAll { $0.field == field }
        filled[bookID] = record.changes.isEmpty ? nil : record
        persistFilled([bookID])
    }

    func undoAllFilled(for bookID: UUID) throws {
        for change in filled[bookID]?.changes ?? [] { try undoFilled(change.field, for: bookID) }
    }

    /// «Está bien»: se queda así y sale de la lista.
    func forgetFilled(_ bookID: UUID) {
        guard filled[bookID] != nil else { return }
        filled[bookID] = nil
        persistFilled([bookID])
    }

    func forgetAllFilled() {
        let keys = Array(filled.keys)
        filled = [:]
        persistFilled(keys)
    }

    /// «Mantener mis datos»: sale de la bandeja sin cambiar nada.
    func dismissReview(_ bookID: UUID) {
        setReview(bookID, candidates: nil)
    }

    // MARK: Duplicados (CB-3)

    /// Los posibles duplicados de la biblioteca, sin los que ya descartaste.
    func duplicateGroups() -> [[Book]] {
        if let duplicatesCache { return duplicatesCache }
        let groups = DuplicateFinder.groups(books, dismissed: notDuplicates)
        duplicatesCache = groups
        return groups
    }

    /// «No son el mismo»: no se vuelve a proponer ninguna pareja de este grupo.
    func dismissDuplicates(_ group: [Book]) {
        var added = Set<DuplicateFinder.Pair>()
        for (i, a) in group.enumerated() {
            for b in group[(i + 1)...] { added.insert(DuplicateFinder.Pair(a.id, b.id)) }
        }
        let table = Dictionary(uniqueKeysWithValues: notDuplicates.union(added).map { ($0, true) })
        notDuplicates = Set(persist(table, keys: added, to: notDuplicatesURL,
                                    read: { (try? JSONDecoder().decode([DuplicateFinder.Pair].self, from: $0)).map { Dictionary($0.map { ($0, true) }, uniquingKeysWith: { a, _ in a }) } },
                                    write: { try? JSONEncoder().encode(Array($0.keys)) }).keys)
    }

    struct MergeReport {
        /// Formatos que el libro no tenía y ahora tiene («PDF»).
        var addedFormats: [String] = []
        /// Archivos repetidos (mismo formato) que se fueron a la Papelera.
        var trashed = 0
        var movedHighlights = 0
    }

    /// Junta varios libros en uno: el que se queda recibe los formatos que no tenía (en su
    /// carpeta, con el nombre de Calibre), los datos que le faltaban, los subrayados y los
    /// marcadores. Un archivo de un formato que ya tenía va a la Papelera (se puede recuperar).
    @discardableResult
    func merge(keep keepID: UUID, others otherIDs: [UUID]) throws -> MergeReport {
        guard var keep = book(id: keepID), let keepFolderPath = keep.folderPath else { throw LibraryError.bookNotFound }
        let keepFolder = root.appendingPathComponent(keepFolderPath, isDirectory: true)
        let others = otherIDs.compactMap { book(id: $0) }.filter { $0.id != keepID }
        var report = MergeReport()

        // 1. El plan, sin tocar nada: qué archivo se mueve a dónde y cuál sobra.
        var formats = Set(keep.formats)
        var moves: [(from: URL, to: URL)] = []
        var leftovers: [URL] = []
        for other in others {
            guard let folder = other.folderPath.map({ root.appendingPathComponent($0, isDirectory: true) }) else { continue }
            for name in [other.filePath.map { ($0 as NSString).lastPathComponent }].compactMap({ $0 }) + other.extraFiles {
                let source = folder.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                let format = (name as NSString).pathExtension.uppercased()
                if formats.contains(format) {
                    leftovers.append(source)
                } else {
                    let target = CalibreLayout.fileName(title: keep.title, authors: keep.authors,
                                                        fileExtension: (name as NSString).pathExtension)
                    guard !FileManager.default.fileExists(atPath: keepFolder.appendingPathComponent(target).path) else {
                        throw LibraryError.folderTaken
                    }
                    moves.append((source, keepFolder.appendingPathComponent(target)))
                    keep.extraFiles.append(target)
                    formats.insert(format)
                    report.addedFormats.append(format)
                }
            }
        }

        // 2. Mover y guardar al que se queda. Si algo falla, todo regresa a su lugar (RB-5).
        var done: [(from: URL, to: URL)] = []
        do {
            for move in moves {
                try FileManager.default.moveItem(at: move.from, to: move.to)
                done.append(move)
            }
            if coverURL(for: keep) == nil, let cover = others.lazy.compactMap({ self.coverURL(for: $0) }).first {
                try? FileManager.default.copyItem(at: cover, to: keepFolder.appendingPathComponent(CalibreLayout.coverFileName))
            }
            keep = try update(DuplicateFinder.merged(keep: keep, with: others))
        } catch {
            let folder = book(id: keepID)?.folderPath.map { root.appendingPathComponent($0, isDirectory: true) } ?? keepFolder
            for move in done.reversed() {
                try? FileManager.default.moveItem(at: folder.appendingPathComponent(move.to.lastPathComponent), to: move.from)
            }
            throw error
        }

        // 3. Ya juntos: lo de los otros pasa al que se queda y lo que sobra va a la Papelera.
        for other in others {
            // Subrayados: pasan al que se queda y se vuelven a anclar por su cita (el archivo es otro).
            for var annotation in AnnotationStore.shared.annotations(forBook: other.id) where annotation.bookID == other.id {
                annotation.bookID = keepID
                annotation.cfi = nil
                try? AnnotationStore.shared.save(annotation)
                report.movedHighlights += 1
            }
            for var bookmark in bookmarks(for: other.id) {
                removeBookmark(id: bookmark.id)
                bookmark.id = UUID()
                bookmark.bookID = keepID
                addBookmark(bookmark)
            }
            // La lápida dice en quién se juntó: tus otros dispositivos le pasan sus subrayados.
            record([Book.deletion(id: other.id, clock: clock),
                    Change(hlc: clock.tick(), entity: .book, entityID: other.id, field: Self.mergedIntoField,
                           value: .string(keepID.uuidString))])
            setReview(other.id, candidates: nil)
        }
        for file in leftovers where (try? Self.discard(file)) != nil { report.trashed += 1 }
        // Lo que queda de sus carpetas (portada y metadata.opf) también va a la Papelera.
        for folder in others.compactMap({ $0.folderPath.map { root.appendingPathComponent($0, isDirectory: true) } })
        where FileManager.default.fileExists(atPath: folder.path) && !FolderMove.sameIgnoringCase(folder, keepFolder) {
            try? Self.discard(folder)
            removeIfEmpty(folder.deletingLastPathComponent())
        }
        books = state.books()
        return report
    }

    static let mergedIntoField = "merged_into"

    /// Los libros que se juntaron en este, aquí o en otro dispositivo.
    func booksMerged(into id: UUID) -> [UUID] {
        mergedInto[id] ?? []
    }

    /// A la Papelera en la Mac (se puede recuperar); en el iPhone no hay Papelera.
    private static func discard(_ url: URL) throws {
        #if os(macOS)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        try FileManager.default.removeItem(at: url)
        #endif
    }

    // MARK: Buscar datos en lote (CB-4)

    /// Los libros a los que les falta portada, sinopsis, ISBN, editorial o año.
    func incompleteBooks() -> [UUID] {
        if let incompleteCache { return incompleteCache }
        let ids = books.filter { BatchLookup.needsData($0, hasCover: coverURL(for: $0) != nil) }.map(\.id)
        incompleteCache = ids
        return ids
    }

    /// Busca datos para muchos libros, uno tras otro y con pausa para no saturar Open Library.
    /// Lo seguro se completa solo; lo dudoso va a «Por revisar». Sin internet, lo que falta
    /// queda pendiente y se reintenta solo. Una búsqueda en lote a la vez.
    func lookUpMany(_ ids: [UUID]) {
        guard batchTask == nil else { return }
        let ids = ids.filter { book(id: $0) != nil }
        guard !ids.isEmpty else { return }
        batch = BatchLookup.Progress(total: ids.count)
        // Cada lote con su ficha: uno detenido que termina tarde no toca al siguiente (RB-5).
        let token = UUID()
        batchToken = token
        batchTask = Task { [weak self] in
            var unreachableInARow = 0
            for (index, id) in ids.enumerated() {
                guard let self, !Task.isCancelled, self.batchToken == token else { break }
                let decision = await self.identify(id)
                guard self.batchToken == token else { break }
                self.batch?.record(decision)
                // Un tropiezo de un servidor no detiene todo; tres seguidos es que no hay internet.
                unreachableInARow = decision == .unreachable ? unreachableInARow + 1 : 0
                if unreachableInARow >= BatchLookup.unreachableLimit {
                    let rest = ids.dropFirst(index + 1)
                    for other in rest { self.setPending(other, true) }
                    self.batch?.pending += rest.count
                    break
                }
                try? await Task.sleep(for: BatchLookup.pause)
            }
            if self?.batchToken == token {
                self?.batchTask = nil
                self?.batchToken = nil
            }
        }
    }

    /// Detiene la búsqueda en lote; lo ya completado se queda.
    func stopBatch() {
        batchTask?.cancel()
        batchTask = nil
        batchToken = nil
        batch?.stopped = true
    }

    /// Quita el aviso del resultado.
    func clearBatch() {
        guard batchTask == nil else { return }
        batch = nil
    }

    /// Vuelve a buscar los libros que se quedaron sin buscar por falta de internet.
    func retryPendingLookups() async {
        for id in pendingLookup where book(id: id) != nil {
            if await identify(id) == .unreachable { break }
        }
    }

    private var reviewsURL: URL {
        root.appendingPathComponent(".lectora/por-revisar.json")
    }

    private var filledURL: URL {
        root.appendingPathComponent(".lectora/completados.json")
    }

    private var rulesURL: URL {
        root.appendingPathComponent(".lectora/reglas.json")
    }

    private var notDuplicatesURL: URL {
        root.appendingPathComponent(".lectora/no-duplicados.json")
    }

    private var shelvesURL: URL {
        root.appendingPathComponent(".lectora/estantes.json")
    }

    private var pendingURL: URL {
        root.appendingPathComponent(".lectora/por-buscar.json")
    }

    private func setReview(_ bookID: UUID, candidates: [MetadataCandidate]?) {
        reviews[bookID] = candidates
        reviews = persist(reviews, keys: [bookID], to: reviewsURL,
                          read: { try? JSONDecoder().decode([UUID: [MetadataCandidate]].self, from: $0) },
                          write: { try? JSONEncoder().encode($0) })
    }

    private func persistFilled(_ keys: [UUID]) {
        filled = persist(filled, keys: keys, to: filledURL,
                         read: { try? JSONDecoder().decode([UUID: FilledRecord].self, from: $0) },
                         write: { try? JSONEncoder().encode($0) })
    }

    private func setPending(_ bookID: UUID, _ pending: Bool) {
        guard pendingLookup.contains(bookID) != pending else { return }
        if pending { pendingLookup.insert(bookID) } else { pendingLookup.remove(bookID) }
        let table = Dictionary(uniqueKeysWithValues: pendingLookup.map { ($0, true) })
        pendingLookup = Set(persist(table, keys: [bookID], to: pendingURL,
                                    read: { (try? JSONDecoder().decode(Set<UUID>.self, from: $0)).map { Dictionary(uniqueKeysWithValues: $0.map { ($0, true) }) } },
                                    write: { try? JSONEncoder().encode(Set($0.keys)) }).keys)
    }

    /// RB-3: escribe solo las claves que cambiaron aquí, encima de lo que ya hay en el
    /// disco. Lo que otro dispositivo guardó mientras tanto (por iCloud) no se pisa.
    private func persist<K: Hashable, V>(_ mine: [K: V], keys: some Sequence<K>, to url: URL,
                                         read: (Data) -> [K: V]?, write: ([K: V]) -> Data?) -> [K: V] {
        let disk = FolderMove.merge(disk: (try? Data(contentsOf: url)).flatMap(read) ?? [:], mine: mine, changed: keys)
        if let data = write(disk) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        return disk
    }

    private func loadReviews() {
        if let data = try? Data(contentsOf: reviewsURL),
           let saved = try? JSONDecoder().decode([UUID: [MetadataCandidate]].self, from: data) {
            reviews = books.isEmpty ? saved : saved.filter { book(id: $0.key) != nil }
        }
        if let data = try? Data(contentsOf: pendingURL), let saved = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            pendingLookup = books.isEmpty ? saved : saved.filter { book(id: $0) != nil }
        }
        if let data = try? Data(contentsOf: filledURL),
           let saved = try? JSONDecoder().decode([UUID: FilledRecord].self, from: data) {
            filled = books.isEmpty ? saved : saved.filter { book(id: $0.key) != nil }
        }
        if let data = try? Data(contentsOf: rulesURL), let saved = try? JSONDecoder().decode(MetadataRules.self, from: data) {
            rules = saved
        }
        if let data = try? Data(contentsOf: shelvesURL), let saved = try? JSONDecoder().decode([SavedShelf].self, from: data) {
            shelves = Self.ordered(Self.shelfTable(saved))
        }
        if let data = try? Data(contentsOf: notDuplicatesURL),
           let saved = try? JSONDecoder().decode(Set<DuplicateFinder.Pair>.self, from: data) {
            notDuplicates = saved
        }
    }

    // MARK: Posición de lectura

    struct ReadingPosition {
        var cfi: String?
        var fraction: Double
        /// Las primeras palabras de la página, para «Donde lo dejaste».
        var excerpt: String?
        var updatedAt: Date? = nil
    }

    func position(for bookID: UUID) -> ReadingPosition? {
        guard let fields = state.fields(of: .progress, id: bookID) else { return nil }
        return ReadingPosition(
            cfi: fields["cfi"]?.stringValue,
            fraction: fields["fraction"]?.doubleValue?.readingFraction ?? 0,
            excerpt: fields["excerpt"]?.stringValue,
            updatedAt: fields["updated_at"]?.doubleValue.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Guarda dónde vas (en el mismo registro que se sincroniza).
    func savePosition(_ position: ReadingPosition, for bookID: UUID) {
        guard let fraction = position.fraction.readingFraction else { return }
        let values: [(String, JSONValue)] = [
            ("cfi", position.cfi.map(JSONValue.string) ?? .null),
            ("fraction", .number(fraction)),
            ("excerpt", position.excerpt.map(JSONValue.string) ?? .null),
            ("updated_at", .number(Date().timeIntervalSince1970)),
        ]
        let changes = values.map { Change(hlc: clock.tick(), entity: .progress, entityID: bookID, field: $0.0, value: $0.1) }
        try? log.append(changes)
        state.apply(changes)
        objectWillChange.send()
    }

    // MARK: Interno

    private func writeOPF(_ book: Book, hasCover: Bool) throws {
        guard let folder = book.folderPath else { return }
        let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.opfFileName)
        try Data(CalibreOPF.write(book, hasCover: hasCover).utf8).write(to: url, options: .atomic)
    }

    private func record(_ book: Book) throws {
        // Solo los campos que cambiaron: una copia vieja de otro dispositivo no pisa lo demás (RB-3).
        let changes = book.changes(from: self.book(id: book.id), clock: clock)
        guard !changes.isEmpty else { return }
        try log.append(changes)
        state.apply(changes)
        books = state.books()
    }

    private func removeIfEmpty(_ folder: URL) {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? ["?"]
        if contents.filter({ $0 != ".DS_Store" }).isEmpty { try? FileManager.default.removeItem(at: folder) }
    }

    nonisolated static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Trabajos para servicios externos (arquitectura D7)

extension LibraryStore {
    /// Lista compartida de trabajos: cada uno lo hace un solo dispositivo.
    nonisolated static let jobBoard = JobBoard()

    /// Anota un trabajo (si ya existía y está hecho, lo vuelve a abrir con los datos nuevos).
    func enqueueJob(kind: String, target: String, payload: JSONValue = .null, reopen: Bool = false) {
        let id = JobBoard.jobID(kind: kind, target: target)
        var changes = Self.jobBoard.enqueue(kind: kind, target: target, payload: payload, in: state, clock: clock)
        if changes.isEmpty, reopen, let job = JobBoard.job(id: id, in: state), job.done || job.payload != payload {
            changes = Self.jobBoard.reopen(id, payload: payload, clock: clock)
        }
        record(changes)
    }

    /// Toma los trabajos libres de estos tipos y devuelve los que ya le tocan a este dispositivo.
    func takeJobs(kinds: Set<String>) -> [Job] {
        let device = AnnotationStore.deviceID
        for job in Self.jobBoard.claimable(in: state, device: device) where kinds.contains(job.kind) {
            record(Self.jobBoard.claim(job.id, device: device, clock: clock))
        }
        return Self.jobBoard.runnable(in: state, device: device).filter { kinds.contains($0.kind) }
    }

    func pendingJobs(kinds: Set<String>) -> [Job] {
        JobBoard.jobs(in: state).filter { !$0.done && kinds.contains($0.kind) }
    }

    func completeJob(_ job: Job) {
        record(Self.jobBoard.complete(job.id, device: AnnotationStore.deviceID, clock: clock))
    }

    func failJob(_ job: Job, error: Error) {
        record(Self.jobBoard.fail(job, device: AnnotationStore.deviceID, error: error.localizedDescription, clock: clock))
    }

    private func record(_ changes: [Change]) {
        guard !changes.isEmpty else { return }
        try? log.append(changes)
        state.apply(changes)
        if changes.contains(where: { $0.field == Self.mergedIntoField }) { rebuildMergedInto() }
    }
}

// MARK: - Migración de Calibre (arquitectura D3)

/// Cómo fue traer una biblioteca de Calibre.
struct CalibreMigrationReport {
    var imported = 0
    var alreadyHere = 0
    var annotations = 0
    /// Libros sin ningún archivo en Calibre.
    var withoutFiles: [String] = []
    /// Libros que no se pudieron copiar, con el porqué.
    var failed: [(title: String, reason: String)] = []
}

extension LibraryStore {
    /// Trae una biblioteca de Calibre: copia cada carpeta de libro tal cual
    /// (archivos, portada), conserva su número de Calibre si está libre, escribe
    /// su OPF al día y anota el libro y sus subrayados en tu Gabinete. La
    /// biblioteca de Calibre no se toca.
    func migrateFromCalibre(_ source: URL, plan: CalibreMigrationPlan,
                            annotations: AnnotationStore) async -> CalibreMigrationReport {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        var report = CalibreMigrationReport()
        report.alreadyHere = plan.alreadyHere.count
        report.withoutFiles = plan.withoutFiles.map(\.book.title)
        progress = (0, plan.toImport.count)
        defer { progress = nil }

        var lastID = books.compactMap(\.calibreID).max() ?? 0
        for (index, entry) in plan.toImport.enumerated() {
            var book = rules.apply(to: entry.book)
            var calibreID = entry.book.calibreID ?? lastID + 1
            var folder = entry.folder
            // Número libre en el catálogo y en el disco: otro dispositivo pudo usar esa carpeta.
            while books.contains(where: { $0.calibreID == calibreID })
                || FileManager.default.fileExists(atPath: root.appendingPathComponent(folder).path) {
                lastID = max(lastID, books.compactMap(\.calibreID).max() ?? 0) + 1
                calibreID = lastID
                folder = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
            }
            lastID = max(lastID, calibreID)
            book.calibreID = calibreID

            let from = source.appendingPathComponent(entry.folder, isDirectory: true)
            let to = root.appendingPathComponent(folder, isDirectory: true)
            guard let preferred = entry.preferredFile else { continue }
            let fileName = (preferred as NSString).lastPathComponent
            do {
                book.fileHash = try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: from, to: to)
                    return try LibraryStore.sha256(of: to.appendingPathComponent(fileName))
                }.value
                book.filePath = "\(folder)/\(fileName)"
                // Los demás formatos de Calibre también quedan en la ficha (CB-3).
                book.extraFiles = entry.formats.values.map { ($0 as NSString).lastPathComponent }
                    .filter { $0 != fileName }.sorted()
                let hasCover = FileManager.default.fileExists(atPath: to.appendingPathComponent(CalibreLayout.coverFileName).path)
                try writeOPF(book, hasCover: hasCover)
                try record(book)
                for highlight in entry.annotations {
                    try? annotations.save(Annotation(bookID: book.id, cfi: nil, quote: highlight.text, color: "pencil",
                                                     note: highlight.note, createdAt: highlight.createdAt ?? Date(),
                                                     source: "calibre"))
                    report.annotations += 1
                }
                report.imported += 1
            } catch {
                // La carpeta estaba libre antes de copiar: lo que haya ahí es de esta corrida.
                try? FileManager.default.removeItem(at: to)
                removeIfEmpty(to.deletingLastPathComponent())
                report.failed.append((entry.book.title, error.localizedDescription))
            }
            progress = (index + 1, plan.toImport.count)
        }
        return report
    }
}

// MARK: - Marcadores

extension LibraryStore {
    func bookmarks(for bookID: UUID) -> [Bookmark] {
        state.bookmarks(for: bookID)
    }

    func addBookmark(_ bookmark: Bookmark) {
        record(bookmark.changes(clock: clock))
        objectWillChange.send()
    }

    func removeBookmark(id: UUID) {
        record([Bookmark.deletion(id: id, clock: clock)])
        objectWillChange.send()
    }
}
