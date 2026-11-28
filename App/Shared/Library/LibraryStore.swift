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
        /// Un archivo del libro sigue en iCloud sin bajar: no se junta hasta que llegue.
        case stillDownloading(title: String)
        /// Otro trabajo de toda la biblioteca está corriendo (auditoría 4): «Ordenar», mover el
        /// Gabinete, traer de Calibre o añadir libros.
        case busy(LibraryWork)
        /// Tu biblioteca sigue bajando de iCloud (auditoría 6): con la lista a medias, lo que traigo
        /// o añado saldría repetido y con el número de Calibre de otro libro.
        case downloadingFromCloud
        var errorDescription: String? {
            switch self {
            case .busy(let work): work.reason
            case .downloadingFromCloud: EmptyCopy.addWhileDownloading
            case .stillDownloading(let title):
                "Todavía estoy bajando de iCloud un archivo de «\(title.isolated)». Vuelve a intentarlo en un momento."
            case .unreadable(let name, let reason): "«\(name.isolated)» no entró a tu biblioteca. \(reason)"
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
    /// La vuelta que busca de nuevo lo pendiente (auditoría 7, M4): una a la vez.
    private var lookupRetry: Task<Void, Never>?
    private var lookupRetryToken: UUID?
    /// Registros de internet que deshiciste en un libro («openlibrary:OL1W»): ya no se le
    /// aplican solos; si vuelven a salir, van a «Por revisar» (auditoría 1).
    private var declined: [UUID: Set<String>] = [:]
    /// Lo que espera a que iCloud baje su archivo (auditoría 1), guardado en el dispositivo y
    /// por Gabinete: no se pierde aunque cierres la app (auditoría 2).
    private var pendingWrites: PendingWrites
    /// Reintenta lo pendiente cada poco mientras iCloud baja.
    private var retryTask: Task<Void, Never>?
    /// Libro que se quedó → los que se juntaron en él (RB-3: sus subrayados lo siguen).
    private var mergedInto: [UUID: [UUID]] = [:]
    /// Lo escrito mientras el registro se lee en segundo plano (auditoría de medios).
    private var writesDuringRead = WritesDuringRead()
    /// Un aviso para ti (p. ej. un archivo de `.lectora/` que no puedo leer). La interfaz lo
    /// enseña con `noticeAlert` y lo vuelve a nil.
    @Published var notice: String?
    /// El título de ese aviso: cada aviso con el suyo (auditoría 5: el de iCloud decía «No pude
    /// leer un archivo de tu Gabinete»).
    @Published private(set) var noticeTitle = LibraryStore.damagedNoticeTitle
    static let damagedNoticeTitle = "No pude leer un archivo de tu Gabinete"
    /// Dice lo mismo que el aviso: algo sí llegó, falta lo demás (auditoría 6: «no ha bajado» y
    /// luego «ya llegaron 12»).
    static let cloudGaveUpTitle = "Todavía falta parte de tu biblioteca"
    /// Los archivos dañados de los que ya te avisé en esta sesión.
    private var damagedNoticed: Set<String> = []
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
    var moving: Bool { lock.current == .moving }
    /// Un trabajo de toda la biblioteca a la vez (auditoría 4): mientras «Ordenar», mover el
    /// Gabinete, traer de Calibre o añadir libros corre, lo demás de esa lista no empieza (y lo
    /// que añades espera su turno). Lo que editas sí se guarda, sobre lo más reciente.
    @Published private(set) var lock = WorkLock()
    /// Por qué no puedo empezar otro de esos trabajos ahora (nil si puedo).
    var busyReason: String? { lock.current?.reason }
    /// Lo que espera a que se suelte el candado (lo que añadiste mientras ordenaba).
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    /// Toma el candado, esperando a que termine el trabajo que lo tenga.
    private func waitForLock(_ work: LibraryWork) async {
        while !lock.begin(work) {
            await withCheckedContinuation { lockWaiters.append($0) }
        }
    }

    /// Espera a que ningún trabajo de toda la biblioteca tenga el candado (sin tomarlo). Si quien
    /// espera se va (cerraste la pantalla), deja de esperar ya (auditoría 8, B3): antes se quedaba
    /// colgado hasta que el trabajo terminara.
    func waitUntilIdle() async {
        while lock.current != nil, !Task.isCancelled {
            let id = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    if Task.isCancelled { continuation.resume() } else { idleWaiters[id] = continuation }
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.idleWaiters.removeValue(forKey: id)?.resume() }
            }
        }
    }
    /// Lo que espera a que la biblioteca esté libre, cada uno con su ficha para soltarlo si se va.
    private var idleWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// Toma el candado ya, o falla con el porqué.
    private func takeLock(_ work: LibraryWork) throws {
        if let current = lock.current { throw LibraryError.busy(current) }
        _ = lock.begin(work)
    }

    private func releaseLock(_ work: LibraryWork) {
        lock.end(work)
        let waiting = lockWaiters
        lockWaiters = []
        waiting.forEach { $0.resume() }
        let idle = idleWaiters
        idleWaiters = [:]
        idle.values.forEach { $0.resume() }
        // Lo que se quedó sin guardar mientras corría (auditoría 6, M2) se busca de nuevo ya, no
        // hasta volver a abrir la app.
        // Una sola vuelta a la vez y con pausa entre libros (auditoría 7, M4): antes cada candado
        // que se soltaba lanzaba otra, sin pausa, y salían cientos de consultas seguidas.
        if lock.current == nil, !pendingLookup.isEmpty, lookupRetry == nil {
            Task { [weak self] in await self?.retryPendingLookups() }
        }
    }

    /// Mientras muevo el Gabinete no se guarda ningún cambio de un libro: una carpeta que cambia
    /// de nombre se quedaría en la copia vieja. Se mira antes de tocar nada (auditoría 6, B4).
    private func ensureCanEdit() throws {
        if lock.current == .moving { throw LibraryError.busy(.moving) }
    }

    /// Un aviso con su título (lo que no hice y por qué), en el iPhone y en la Mac.
    func explain(_ title: String, _ message: String) {
        noticeTitle = title
        notice = message
    }

    /// Falla con el porqué si otro trabajo de toda la biblioteca está corriendo.
    private func ensureIdle() throws {
        if let current = lock.current { throw LibraryError.busy(current) }
    }
    private var log: ChangeLog
    private let clock: HybridLogicalClock
    private var state = LibraryState()
    private lazy var extractor = MetadataExtractor()
    /// Importaciones en fila: una termina antes de que empiece la siguiente.
    private var lastImport: Task<[Result<ImportOutcome, Error>], Never>?

    init(root: URL = LibraryStore.defaultRoot) {
        self.root = root
        pendingWrites = PendingWrites.forCabinet(root.deletingLastPathComponent())
        try? FileManager.default.createDirectory(at: root.deletingLastPathComponent()
            .appendingPathComponent(CabinetLocation.notesFolder), withIntermediateDirectories: true)
        let device = AnnotationStore.deviceID
        log = ChangeLog(directory: root.appendingPathComponent(".lectora/registro", isDirectory: true), deviceID: device)
        clock = HybridLogicalClock(node: device)
        reload()
        removeLeftoverCopies()
    }

    /// Quita las carpetas de trabajo que dejó un movimiento que no terminó (la app se cerró o se
    /// trabó a media copia, auditoría 7, M2): en el Gabinete en uso y en cada carpeta a la que
    /// este aparato empezó a copiar. Solo las de nombre exacto `.gabinete-copia-<token>-…`; las de
    /// otro aparato, cuando llevan un día sin tocarse (podría estar copiando ahora). Y las de un
    /// libro nuevo que no terminó de copiarse (`.gabinete-nuevo-<uuid>`, auditoría 9), cuando llevan
    /// unos minutos sin tocarse y ningún trabajo de toda la biblioteca corre.
    private func removeLeftoverCopies() {
        let pending = CabinetLocation.pendingStagings()
        let mine = Set(pending.map(\.token))
        let places = [cabinet] + pending.compactMap(\.destination)
        let folders = [CabinetLocation.libraryFolder, CabinetLocation.notesFolder]
        let library = root, busy = lock.isBusy
        Task.detached(priority: .utility) {
            for place in places {
                let accessing = place.startAccessingSecurityScopedResource()
                StagedMove.removeLeftovers(in: place, folders: folders, mine: mine)
                if accessing { place.stopAccessingSecurityScopedResource() }
            }
            FolderMove.removeNewLeftovers(in: library, busy: busy)
            await MainActor.run { CabinetLocation.forgetStaging(tokens: mine) }
        }
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
        /// Hay archivos en iCloud sin bajar: copiarlos copiaría marcadores vacíos, no los libros.
        case stillInCloud(Int)
        /// Hay cambios guardados en el dispositivo que todavía no llegan a la carpeta: en la
        /// carpeta nueva se quedarían fuera (auditoría 3).
        case pendingChanges
        /// Tu biblioteca sigue bajando de iCloud (auditoría 8, A2): moverla copiaría una lista a
        /// medias, y cambiar de carpeta dejaría a medias lo que baja.
        case downloadingLibrary
        var errorDescription: String? {
            switch self {
            case .occupied(let folder):
                "Esa carpeta ya tiene una carpeta «\(folder.isolated)». Para no tocarla, elige otra carpeta o crea una nueva para tu Gabinete."
            case .insideItself:
                "No puedo mover el Gabinete dentro de sí mismo. Elige una carpeta que esté fuera de él."
            case .alreadyHasLibrary:
                "Esa carpeta ya tiene una biblioteca de Gabinete. Ábrela en vez de mover la tuya encima."
            case .incomplete(let copied, let expected):
                "Solo copié \(copied) de \(expected) elementos. Tu biblioteca sigue donde estaba."
            case .downloadingLibrary:
                EmptyCopy.cabinetWhileDownloading
            case .pendingChanges:
                "Todavía estoy guardando en tu Gabinete cambios que esperan a iCloud. No moví nada: "
                    + "vuelve a intentarlo en un momento, con conexión y la app abierta."
            case .stillInCloud(let count):
                "Todavía estoy bajando de iCloud \(count.counted("archivo", "archivos")) de tu Gabinete. No moví nada: "
                    + "vuelve a intentarlo cuando terminen de bajar (con conexión, la app abierta)."
            }
        }
    }

    /// Lleva la biblioteca (y las notas) a otra carpeta y la usa desde ahí. Se
    /// copia todo, se comprueba y solo entonces se borra la copia local.
    func move(toCabinet destination: URL) async throws {
        // Mientras bajo tu biblioteca de iCloud no muevo ni cambio de Gabinete (auditoría 8, A2).
        guard !waitingForCloud else { throw LocationError.downloadingLibrary }
        CabinetLocation.startAccessing(destination)
        guard !CabinetLocation.hasLibrary(in: destination) else { throw LocationError.alreadyHasLibrary }
        try Self.checkMove(from: cabinet, to: destination)
        // Un trabajo a la vez (auditoría 4): lo que añades espera a que termine.
        try takeLock(.moving)
        defer { releaseLock(.moving) }
        // Lo que se escribiera a medio camino se quedaría en la copia vieja.
        haltBatch()
        let source = cabinet
        let wasLocal = isLocal
        // Lo que sigue en iCloud se baja primero; si no termina, no se mueve nada (auditoría de medios).
        let folders = [CabinetLocation.libraryFolder, CabinetLocation.notesFolder].map { source.appendingPathComponent($0) }
        let waiting = await Self.downloadAll(in: folders)
        guard waiting == 0 else { throw LocationError.stillInCloud(waiting) }
        // Lo que esperaba a iCloud se escribe ahora en la carpeta vieja, para que viaje en la copia:
        // lo pendiente vive en el dispositivo por Gabinete y, tras el cambio, nadie lo escribiría.
        retryWaitingFiles()
        SessionStore.shared.writePending()
        guard !hasWaitingFiles, !pendingWrites.has(SessionStore.pendingName) else { throw LocationError.pendingChanges }
        // Lo que guardes mientras copio (la página, una sesión, una nota) se pasa a la copia antes
        // de borrar la vieja (auditoría 4): se copia lo cambiado desde que empecé.
        let started = Date().addingTimeInterval(-Self.catchUpMargin)
        let topFolders = [CabinetLocation.libraryFolder, CabinetLocation.notesFolder]
        let catchUp = Self.catchUpFolders
        // Se copia a carpetas de trabajo hermanas y solo al final se ponen en su lugar (auditoría 6):
        // todo lo que tienen es de esta corrida. Antes se copiaba directo a «Biblioteca» y «Notas»;
        // si iCloud bajaba ahí las de otro aparato a media copia, se contaban como mías y, si algo
        // fallaba, se borraban. Si falla, se quitan solo las de trabajo.
        let staged = StagedMove(destination: destination, folders: topFolders)
        // Si la app se cierra a media copia, al abrirla quito la carpeta de trabajo (auditoría 7).
        let earlier = Set(CabinetLocation.pendingStagings().map(\.token))
        CabinetLocation.rememberStaging(token: staged.token, destination: destination)
        defer { CabinetLocation.forgetStaging(tokens: [staged.token]) }
        // Lo que la app escribe mientras muevo queda anotado: la última pasada copia solo eso.
        let journal = WriteJournal.shared
        journal.begin()
        defer { journal.end() }
        do {
            let incomplete = try await Task.detached(priority: .userInitiated) { () -> (copied: Int, expected: Int)? in
                let manager = FileManager.default
                try manager.createDirectory(at: destination, withIntermediateDirectories: true)
                // Lo que dejó ahí un movimiento anterior que no terminó, antes de copiar (auditoría 7).
                StagedMove.removeLeftovers(in: destination, folders: topFolders, mine: earlier)
                var expected = 0, copied = 0, complete = true
                for folder in topFolders {
                    let from = source.appendingPathComponent(folder), to = staged.staging(folder)
                    guard manager.fileExists(atPath: from.path) else { continue }
                    try LibraryStore.coordinatedCopy(from: from, to: to)
                    // La cuenta sale de la misma lectura que la copia (auditoría 5): una nota que
                    // creas justo después no la hace fallar; la pasa la última pasada. La carpeta de
                    // trabajo es toda de esta corrida: lo que sobre se quita y la cuenta lo comprueba.
                    let pass = try FolderCatchUp.sync(from: from, to: to, since: started)
                    expected += pass.expected
                    copied += pass.present
                    complete = complete && pass.isComplete
                }
                return complete ? nil : (copied, expected)
            }.value
            // Ni de menos ni de más: cada cosa del origen está en la copia y la copia no tiene nada
            // que no esté en el origen.
            if let incomplete { throw LocationError.incomplete(copied: incomplete.copied, expected: incomplete.expected) }
            // El recorrido grande de lo que se escribe mientras usas la app, en segundo plano
            // (auditoría 5): antes iba en el hilo de la interfaz y la app se trababa. Lo que
            // escribas mientras recorro lo anota el diario y lo copio abajo.
            _ = journal.drain()
            var mine = try await Task.detached(priority: .userInitiated) { () -> [String: Set<String>] in
                var mine: [String: Set<String>] = [:]
                for folder in catchUp {
                    let from = source.appendingPathComponent(folder), to = staged.staged(folder)
                    guard FileManager.default.fileExists(atPath: from.path) else { continue }
                    var copied = FolderCatchUp.snapshot(of: to)
                    try FolderCatchUp.sync(from: from, to: to, since: started, copied: &copied)
                    mine[folder] = copied
                }
                return mine
            }.value
            // Lo que escribiste durante el recorrido (pocos archivos), antes de ponerlas en su lugar;
            // lo que escribas mientras las pongo lo copio después, ya sin soltar el hilo.
            let written = journal.drain()
            for folder in catchUp {
                let from = source.appendingPathComponent(folder), to = staged.staged(folder)
                guard FileManager.default.fileExists(atPath: from.path) else { continue }
                try FolderCatchUp.copy(written, from: from, to: to, copied: &mine[folder, default: []])
            }
            // A su lugar, sin pisar lo que haya llegado mientras tanto. Fuera del hilo de la interfaz
            // (auditoría 8, M2): con iCloud, avisarle a cada proveedor puede tardar y la app se trababa.
            let placed: [String]
            do {
                placed = try await Task.detached(priority: .userInitiated) { try staged.place() }.value
            } catch StagedMove.Failure.occupied(let folder) {
                throw LocationError.occupied(folder)
            }
            // Cada carpeta que copié está en su lugar: si una carpeta de trabajo desapareció (la quitó
            // alguien más), no doy el movimiento por hecho ni borro tu copia de aquí.
            let missing = topFolders.filter {
                FileManager.default.fileExists(atPath: source.appendingPathComponent($0).path) && !placed.contains($0)
            }
            guard missing.isEmpty else {
                await Task.detached(priority: .userInitiated) { staged.takeBack(placed) }.value
                throw LocationError.incomplete(copied: placed.count, expected: placed.count + missing.count)
            }
            // Lo que guardaste mientras las ponía en su lugar (el hilo quedó libre) va ya a su lugar
            // nuevo, sin soltar el hilo hasta el cambio: nada se queda en la copia vieja.
            let late = journal.drain()
            do {
                for folder in catchUp where placed.contains(String(folder.split(separator: "/")[0])) {
                    let from = source.appendingPathComponent(folder), to = destination.appendingPathComponent(folder)
                    guard FileManager.default.fileExists(atPath: from.path) else { continue }
                    try FolderCatchUp.copy(late, from: from, to: to, copied: &mine[folder, default: []])
                }
                try CabinetLocation.remember(destination)
            } catch {
                // Lo que puse en su lugar es de esta corrida: regresa a la de trabajo y se quita.
                await Task.detached(priority: .userInitiated) { staged.takeBack(placed) }.value
                throw error
            }
        } catch {
            await Task.detached(priority: .utility) { staged.discard() }.value
            throw error
        }
        staged.finish()
        open(cabinet: destination)
        if wasLocal {
            for folder in topFolders {
                try? FileManager.default.removeItem(at: source.appendingPathComponent(folder))
            }
        }
    }

    /// Lo que se escribe mientras se usa la app (registros, sesiones, notas): al mover, se
    /// vuelve a pasar a la copia justo antes del cambio.
    static let catchUpFolders = [CabinetLocation.libraryFolder + "/.lectora", CabinetLocation.notesFolder]
    /// Margen para la hora de modificación de los archivos (el disco la redondea).
    static let catchUpMargin: TimeInterval = 2

    /// Usa la biblioteca que ya está en esa carpeta (p. ej. la que creó tu Mac).
    func use(cabinet destination: URL) throws {
        try ensureIdle()
        guard !waitingForCloud else { throw LocationError.downloadingLibrary }
        CabinetLocation.startAccessing(destination)
        try CabinetLocation.remember(destination)
        open(cabinet: destination)
    }

    /// Vuelve a la carpeta del dispositivo (no copia nada).
    func useLocalCabinet() throws {
        try ensureIdle()
        guard !waitingForCloud else { throw LocationError.downloadingLibrary }
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
        // Una búsqueda en lote que seguía corriendo escribiría en este Gabinete lo del anterior
        // (auditoría 9, M3): se detiene, y lo que vuelva de internet ya no se guarda (`identify`).
        haltBatch()
        pendingLookup = []
        filled = [:]
        declined = [:]
        rules = MetadataRules()
        shelves = []
        notDuplicates = []
        // Lo pendiente de este Gabinete (no el de la anterior) vuelve y se reintenta.
        pendingWrites = PendingWrites.forCabinet(cabinet)
        pendingCache = nil
        retryTask?.cancel()
        retryTask = nil
        // Lo que esperaba a iCloud era de la anterior (auditoría 4): no se queda esperando aquí.
        rereadTask?.cancel()
        rereadTask = nil
        repairTask?.cancel()
        waitingForCloud = false
        cloudGaveUp = false
        reload()
        refreshFromCloud()
    }

    /// Trae lo que cambió en otros dispositivos: pide a iCloud los registros,
    /// portadas y metadatos que falten y vuelve a leer el catálogo.
    func refreshFromCloud() {
        retryWaitingFiles()
        let folder = root, log = log
        // Lo que guardes mientras se lee no se pierde: se aplica encima de la lectura.
        let token = writesDuringRead.begin()
        Task.detached(priority: .utility) { [weak self] in
            CloudFiles.requestSmallFiles(in: folder)
            try? await Task.sleep(for: CloudFiles.settle)
            // El registro se lee fuera del hilo de la interfaz: con años de lectura pesa (RB, A7).
            let result = try? log.readAll()
            await self?.reload(with: result, token: token, ifStillAt: folder)
        }
    }

    private func reload(with result: ChangeLog.ReadResult?, token: UUID, ifStillAt folder: URL) {
        let written = writesDuringRead.end(token)
        guard root == folder else { return }
        apply(result.map { $0.changes + written }, notDownloaded: result?.notDownloaded ?? [])
    }

    /// Escribe en el registro y lo anota para las lecturas en curso (`refreshFromCloud`).
    private func appendToLog(_ changes: [Change]) throws {
        try log.append(changes)
        writesDuringRead.note(changes)
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

    /// Cuánto espera mover el Gabinete a que iCloud baje lo que falta.
    static let moveDownloadWait: Duration = .seconds(90)

    /// Pide bajar todo lo que sigue en iCloud y espera (hasta `moveDownloadWait`). Devuelve
    /// cuántos archivos siguen sin bajar.
    private static func downloadAll(in folders: [URL]) async -> Int {
        let pending = { await Task.detached(priority: .userInitiated) { folders.flatMap(CloudFile.waiting(in:)) }.value }
        var waiting = await pending()
        guard !waiting.isEmpty else { return 0 }
        waiting.forEach(CloudFile.requestDownload)
        let deadline = ContinuousClock.now + moveDownloadWait
        while !waiting.isEmpty, ContinuousClock.now < deadline {
            try? await Task.sleep(for: CloudFiles.settle)
            waiting = await pending()
        }
        return waiting.count
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
        let result = try? log.readAll()
        apply(result?.changes, notDownloaded: result?.notDownloaded ?? [])
    }

    /// Algún registro sigue en iCloud sin bajar (también el tuyo, en el primer arranque): la
    /// biblioteca dice que está bajando en vez de «Todavía no hay libros» (auditoría 3).
    @Published private(set) var waitingForCloud = false
    /// Esperé a iCloud y no bajó todo (auditoría 4): ya no digo «Bajando tu biblioteca» para
    /// siempre; te enseño lo que llegó y puedes añadir libros. Vuelvo a leer al volver a la app.
    @Published private(set) var cloudGaveUp = false
    private var rereadTask: Task<Void, Never>?
    /// Ya te avisé en esta sesión de que iCloud no bajó todo.
    private var cloudGaveUpNoticed = false

    /// Un registro sin bajar no es un registro vacío (auditoría 3): se pide, se vuelve a leer en
    /// un momento y, mientras, no se quita nada de lo que ya tenías. Si después de esperar sigue
    /// sin bajar, dejo de esperar y te lo digo una vez (auditoría 4).
    private func waitForLogs(_ notDownloaded: [URL]) {
        #if DEBUG
        // Capturas: `-screenshot.cloud downloading|gaveUp` (auditoría 5).
        if let simulated = LaunchOptions.cloud {
            waitingForCloud = simulated == "downloading" || simulated == "gaveUp"
            cloudGaveUp = false
            // «gaveUp» pasa por el mismo camino que de verdad (auditoría 6): así se ve su aviso.
            if simulated == "gaveUp" { giveUpOnCloud() }
            return
        }
        #endif
        guard !notDownloaded.isEmpty else {
            waitingForCloud = false
            cloudGaveUp = false
            rereadTask?.cancel()
            rereadTask = nil
            return
        }
        notDownloaded.forEach(CloudFile.requestDownload)
        guard rereadTask == nil else { return }
        waitingForCloud = true
        cloudGaveUp = false
        let folder = root
        rereadTask = Task { [weak self] in
            for _ in 0..<CloudFiles.waitAttempts {
                try? await Task.sleep(for: CloudFiles.settle)
                guard !Task.isCancelled, let self, self.root == folder, self.waitingForCloud else { return }
                self.reload()
            }
            guard !Task.isCancelled, let self, self.root == folder else { return }
            self.rereadTask = nil
            self.giveUpOnCloud()
        }
    }

    /// Esperé lo que podía: lo que bajó ya se ve; lo demás llega cuando vuelvas a la app.
    private func giveUpOnCloud() {
        guard waitingForCloud else { return }
        waitingForCloud = false
        cloudGaveUp = true
        // Sin libros, el vacío ya lo dice con sus salidas (auditoría 5): el aviso lo tapaba y decía
        // «te enseño lo que ya llegó» sin que llegara nada.
        if !cloudGaveUpNoticed, !books.isEmpty {
            cloudGaveUpNoticed = true
            noticeTitle = Self.cloudGaveUpTitle
            notice = Self.cloudGaveUpNotice(books.count)
        }
    }

    static func cloudGaveUpNotice(_ count: Int) -> String {
        "Todavía no baja de iCloud todo el registro de tu biblioteca. Te enseño \(count == 1 ? "el libro que ya llegó" : "los \(count.counted("libro", "libros")) que ya llegaron") "
            + "y vuelvo a leerlo cuando regreses a la app, con conexión."
    }

    private func apply(_ changes: [Change]?, notDownloaded: [URL] = []) {
        waitForLogs(notDownloaded)
        var fresh = LibraryState()
        // Con algún registro sin bajar, lo que llegó se suma a lo que ya tenías (auditoría 4): se
        // aplican los registros que sí bajaron, las reglas, los estantes y «Por revisar», y ningún
        // libro se quita solo porque falta un registro.
        if !notDownloaded.isEmpty { fresh = state }
        // Sin lectura (el registro no se pudo leer) se parte de lo que ya tenías (auditoría 5): antes
        // se armaba desde cero con solo lo pendiente y los demás libros desaparecían.
        if let changes { fresh.apply(changes) } else { fresh = state }
        // Lo que espera a que tu registro baje también cuenta (auditoría 2).
        fresh.apply(pendingChanges)
        // Si el registro no se pudo leer (iCloud sin bajar, sin red), la biblioteca no se
        // vacía: se queda lo que había (RB-3).
        if fresh.allIDs(of: .book).isEmpty, !books.isEmpty { return }
        if let latest = fresh.latest { clock.receive(latest) }
        state = fresh
        books = fresh.books()
        rebuildMergedInto()
        // «Ordenar» ya corrige las rutas: no se cruzan dos correcciones a la vez (auditoría 4).
        if lock.current != .tidying { repairPathCase() }
        // Estantes, reglas y «Por revisar» también pudieron cambiar en otro dispositivo.
        loadReviews()
    }

    func book(id: UUID) -> Book? { books.first { $0.id == id } }

    /// Rutas guardadas antes con otras mayúsculas que las del disco: se corrigen al abrir, no
    /// solo al editar u «Ordenar» (auditoría de medios). Solo mira los libros que «no están».
    /// Fuera del hilo de la interfaz, con un solo índice del disco, y se guardan todas juntas
    /// (auditoría 3: con 5,000 libros sin bajar congelaba el arranque 18 s y podía cerrar la app).
    private func repairPathCase() {
        let folder = root
        let paths = Dictionary(books.compactMap { book in book.filePath.map { (book.id, $0) } }, uniquingKeysWith: { a, _ in a })
        repairTask?.cancel()
        repairTask = Task { [weak self] in
            let fixes = await Task.detached(priority: .utility) { FolderMove.repairedSpellings(of: paths, in: folder) }.value
            guard !Task.isCancelled, let self, self.root == folder, !fixes.isEmpty else { return }
            self.recordRepairs(fixes, from: paths)
        }
    }
    private var repairTask: Task<Void, Never>?

    /// Guarda de una vez las rutas corregidas; un libro que cambió mientras tanto no se toca.
    private func recordRepairs(_ fixes: [UUID: String], from paths: [UUID: String]) {
        var changes: [Change] = []
        for (id, real) in fixes {
            // Lo más reciente del registro, no la lista que se ve (puede esperar a armarse).
            guard var book = current(id), book.filePath == paths[id] else { continue }
            let before = book
            book.filePath = real
            changes += book.changes(from: before, clock: clock)
        }
        guard !changes.isEmpty, (try? appendToLog(changes)) != nil else { return }
        state.apply(changes)
        books = state.books()
    }

    /// La misma corrección para un solo libro, ya (al deshacer un cambio de carpeta).
    private func repairPathCase(of book: Book) {
        guard var book = current(book.id), let path = book.filePath,
              let real = FolderMove.repairedSpelling(of: path, in: root) else { return }
        book.filePath = real
        try? record(book)
    }

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
        // Mientras bajo tu biblioteca de iCloud no añado nada, por ningún lado (auditoría 6).
        guard !waitingForCloud else { return urls.map { _ in .failure(LibraryError.downloadingFromCloud) } }
        let previous = lastImport
        let task = Task { @MainActor in
            _ = await previous?.value
            // Mientras ordeno, muevo el Gabinete o traigo de Calibre, lo que añades espera su turno
            // (auditoría 4): con una lista vieja, los duplicados y el número de Calibre salían mal.
            await self.waitForLock(.importing)
            // Pudo empezar a bajar mientras esperaba su turno (cambiaste de Gabinete).
            if self.waitingForCloud {
                self.releaseLock(.importing)
                return urls.map { _ -> Result<ImportOutcome, Error> in .failure(LibraryError.downloadingFromCloud) }
            }
            let results = await self.runImport(urls)
            self.releaseLock(.importing)
            return results
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
        // También los formatos que juntaste en otro libro (M4): ese archivo ya está aquí.
        if let existing = books.first(where: { $0.hasFile(hash: hash) }) { return .duplicate(existing) }

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
        // Con el nombre del disco: en el iPhone «julio cortázar/» y «Julio Cortázar/» son dos.
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(FolderMove.diskSpelling(
            of: CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID), in: root)).path) {
            calibreID += 1
        }
        book.calibreID = calibreID
        book.fileHash = hash
        book.addedAt = Date()

        let fileName = CalibreLayout.fileName(title: book.title, authors: book.authors, fileExtension: format)
        // Si ya hay una carpeta del autor con otras mayúsculas, entra a ella y el catálogo guarda
        // el nombre que tiene en el disco (auditoría 2).
        let folder = FolderMove.diskSpelling(of: CalibreLayout.folder(title: book.title, authors: book.authors,
                                                                      calibreID: calibreID), in: root)
        let folderURL = root.appendingPathComponent(folder, isDirectory: true)
        // Solo quito lo que puse yo (auditoría 9, M1): si iCloud baja otra carpeta con ese nombre
        // mientras copio, `placeNew` no la pisa y aquí no se borra.
        var placed = false
        do {
            try FolderMove.createFolder((folder as NSString).deletingLastPathComponent, in: root)
            let cover = extracted.cover.flatMap { CoverImaging.jpeg(from: $0) }
            try FolderMove.placeNew(folderURL, empty: true) { work in
                try FileManager.default.copyItem(at: staging, to: work.appendingPathComponent(fileName))
                if let cover { try cover.write(to: work.appendingPathComponent(CalibreLayout.coverFileName), options: .atomic) }
            }
            placed = true
            book.filePath = "\(folder)/\(fileName)"
            try writeOPF(book, hasCover: cover != nil)
            try record(book)
            return .added(book)
        } catch FolderMove.MoveError.occupied {
            removeIfEmpty(folderURL.deletingLastPathComponent())
            throw LibraryError.folderTaken
        } catch {
            // Nada a medias: si algo falla después de ponerla, la carpeta del libro (la mía) no se queda.
            if placed { try? FileManager.default.removeItem(at: folderURL) }
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
            return "No es un PDF que pueda abrir."
        }
        return nil
    }

    // MARK: Editar

    /// Guarda la edición manual. Si cambian el título o el primer autor, la
    /// carpeta y el archivo se renombran como lo haría Calibre.
    @discardableResult
    func update(_ edited: Book, cover newCover: Data? = nil, spelling index: SpellingIndex? = nil) throws -> Book {
        // Mientras muevo el Gabinete, una carpeta que cambia de nombre se quedaría en la copia vieja.
        try ensureCanEdit()
        // Mientras «Ordenar» o traer de Calibre corre, lo que cambias pasa por su índice del disco
        // (auditoría 5): si no, el trabajo no sabía de la carpeta de autor que tu cambio creó y en el
        // iPhone hacía otra igual con otras mayúsculas.
        let index = index ?? activeSpelling
        // Lo más reciente del registro (auditoría 4): mientras «Ordenar» corre, `books` espera a
        // armarse y una copia vieja revertía lo que cambió después.
        guard let original = current(edited.id) else { throw LibraryError.bookNotFound }
        var book = MetadataCleaner.clean(edited, manual: true)
        // Dónde está el archivo lo sabe el catálogo, no la copia que editaste: si «Ordenar» lo movió
        // mientras tanto, la edición no lo regresa a su carpeta vieja.
        book.filePath = original.filePath
        // Los otros formatos se buscan con el nombre que tienen hoy en el disco, no con el de
        // una copia vieja (deshacer un cambio de autor los dejaba huérfanos, RB-5).
        let onDisk = Dictionary(original.extraFiles.map { (($0 as NSString).pathExtension.lowercased(), $0) },
                                uniquingKeysWith: { first, _ in first })
        book.extraFiles = book.extraFiles.map { onDisk[($0 as NSString).pathExtension.lowercased()] ?? $0 }

        // Si el título o el autor cambiaron, o la carpeta no tiene la forma de Calibre, se recoloca.
        // La ruta vieja, con el nombre que tiene en el disco: si el catálogo la guardó con otras
        // mayúsculas (en la Mac se abría igual), aquí se corrige; «Ordenar» la arregla (auditoría 2).
        if let oldPath = original.filePath.map({ FolderMove.diskSpelling(of: $0, in: root, index: index) }), let calibreID = book.calibreID,
           oldPath != expectedPath(for: book, calibreID: calibreID, fileExtension: (oldPath as NSString).pathExtension) {
            let oldFolder = root.appendingPathComponent((oldPath as NSString).deletingLastPathComponent, isDirectory: true)
            var newFolderPath = CalibreLayout.folder(title: book.title, authors: book.authors, calibreID: calibreID)
            var newFolder = root.appendingPathComponent(newFolderPath, isDirectory: true)
            var newName = CalibreLayout.fileName(title: book.title, authors: book.authors,
                                                 fileExtension: (oldPath as NSString).pathExtension)
            let movesFolder = newFolder.standardizedFileURL != oldFolder.standardizedFileURL
            // Se mueve solo la carpeta de este libro; los demás del autor no se tocan (auditoría 1).
            // Si ya hay una carpeta del autor con otras mayúsculas, el libro entra a ella y el
            // catálogo guarda el nombre que tiene en el disco (auditoría 2).
            if movesFolder {
                do {
                    newFolder = try FolderMove.moveBookFolder(oldFolder, to: newFolder, index: index)
                } catch FolderMove.MoveError.occupied {
                    throw LibraryError.folderTaken
                }
                newFolderPath = newFolder.deletingLastPathComponent().lastPathComponent + "/" + newFolder.lastPathComponent
            }
            let oldFile = newFolder.appendingPathComponent((oldPath as NSString).lastPathComponent)
            // Un libro que sigue en iCloud sin bajar no se renombra: se queda con su nombre y «Ordenar» lo arregla luego.
            if CloudFiles.isPlaceholder(oldFile) { newName = oldFile.lastPathComponent }
            let newFile = newFolder.appendingPathComponent(newName)
            do {
                try FolderMove.move(oldFile, to: newFile)
            } catch {
                // Deshacer el cambio de carpeta: el libro sigue donde estaba.
                if movesFolder, newFolder.standardizedFileURL != oldFolder.standardizedFileURL {
                    // De regreso, sin hacer una gemela del autor (auditoría de medios): si su carpeta
                    // ya no está y hay otra que solo cambia en mayúsculas, vuelve a esa.
                    let oldAuthor = ((oldPath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
                    let author = (try? FolderMove.createFolder(oldAuthor, in: root, index: index)) ?? oldAuthor
                    let back = root.appendingPathComponent(author, isDirectory: true).appendingPathComponent(oldFolder.lastPathComponent)
                    try? FolderMove.move(newFolder, to: back)
                    index?.forget(path: author)
                    index?.forget(newFolder.deletingLastPathComponent())
                    if !FolderMove.sameItem(newFolder.deletingLastPathComponent(), back.deletingLastPathComponent()) {
                        // Con el índice (auditoría 6, M6): si no, seguía viendo la carpeta quitada.
                        FolderMove.removeIfEmpty(newFolder.deletingLastPathComponent(), index: index)
                    }
                    repairPathCase(of: original)
                }
                throw error
            }
            if movesFolder {
                CoverImaging.forget(oldFolder.appendingPathComponent(CalibreLayout.coverFileName))
            }
            index?.forget(newFolder)
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
            // Ya tiene portada: «le faltan datos» se vuelve a calcular (no cambian los libros).
            incompleteCache = nil
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
        /// Por qué no ordené nada (auditoría 9, B5): bajaba tu biblioteca de iCloud u otro trabajo
        /// corría. Nunca un informe vacío que diga «Revisé 0 libros».
        var notDone: String?
    }

    /// «Ordenando tu biblioteca…»: mientras corre, la fila de Ajustes lo dice y no se repite.
    var tidying: Bool { lock.current == .tidying }
    /// Cómo fue el último «Ordenar» (auditoría 4): vive aquí, no en Ajustes, así no se pierde si
    /// sales de Ajustes antes de que termine. Ajustes lo enseña al volver y lo quita al cerrarlo.
    @Published var tidyReport: TidyReport?
    /// Cada cuántos libros «Ordenar» suelta el hilo de la interfaz para que la app responda.
    static let tidyChunk = 40

    /// Ordena la carpeta como lo haría Calibre: cada libro en `Autor/Título (id)`
    /// con su archivo, portada y metadata.opf al día. Avisa de lo que falta y
    /// de lo que sobra, sin borrar nada. Con miles de libros no congela la app (auditoría 3):
    /// el disco se lee una vez por carpeta (`SpellingIndex`), los libros se vuelven a armar una
    /// sola vez al final y cada `tidyChunk` libros la interfaz vuelve a responder. Lo que cambias
    /// mientras corre (aquí o en otro dispositivo) no se revierte: cada libro se vuelve a leer del
    /// registro justo antes de ordenarlo (auditoría 4).
    @discardableResult
    func tidy() async -> TidyReport {
        var report = TidyReport()
        // Mientras bajo tu biblioteca de iCloud no ordeno (auditoría 8): movería carpetas que todavía
        // no llegan, igual que mover el Gabinete, cambiar de carpeta o traer de Calibre.
        guard !waitingForCloud else {
            report.notDone = EmptyCopy.tidyWhileDownloading
            tidyReport = report
            return report
        }
        guard lock.begin(.tidying) else {
            report.notDone = busyReason ?? EmptyCopy.tidyWhileDownloading
            tidyReport = report
            return report
        }
        deferBooks()
        defer {
            resumeBooks()
            tidyReport = report
            releaseLock(.tidying)
        }
        let manager = FileManager.default
        // Gemelas de una versión anterior (disco que distingue mayúsculas): se juntan primero y
        // el catálogo sigue a cada libro que cambió de carpeta.
        let joined = FolderMove.mergeTwinFolders(in: root)
        let ids = state.ids(of: .book)
        for id in ids {
            guard var book = current(id), let folder = book.folderPath, let now = joined[folder], let path = book.filePath else { continue }
            book.filePath = now + "/" + (path as NSString).lastPathComponent
            bulk { try? record(book) }
        }
        let index = SpellingIndex(root: root)
        activeSpelling = index
        defer { activeSpelling = nil }
        for (number, id) in ids.enumerated() {
            if number % Self.tidyChunk == Self.tidyChunk - 1 { await Task.yield() }
            // Lo de ahora, no lo de cuando empecé: lo que editaste o juntaste mientras tanto manda
            // (un libro que se juntó en otro ya no está y no sale como «sin archivo»).
            guard let book = current(id), let path = book.filePath, book.calibreID != nil else { continue }
            report.checked += 1
            guard CloudFile.isTaken(root.appendingPathComponent(path)) else {
                report.missing.append(book.title)
                continue
            }
            // Solo cuenta si de verdad cambió de lugar (un autor que solo cambia mayúsculas puede
            // quedarse en su carpeta si comparte disco con otros libros).
            if let updated = bulk({ try? update(book, spelling: index) }), updated.filePath != path { report.relocated += 1 }
        }
        let known = Set(state.ids(of: .book).compactMap { current($0)?.folderPath })
        let authors = (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for author in authors where !author.lastPathComponent.hasPrefix(".") && author.hasDirectoryPath {
            let titles = (try? manager.contentsOfDirectory(at: author, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            // Una carpeta de trabajo escondida (`.gabinete-nuevo-…`) no es un libro suelto.
            for title in titles where title.hasDirectoryPath && !title.lastPathComponent.hasPrefix(".") {
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
        // Desde «Elige los datos», con un trabajo de toda la biblioteca corriendo, no busco ni dejo
        // candidatos (se guardarían en la copia que se mueve): digo «ocupado» y la pantalla lo
        // vuelve a buscar sola al terminar (auditoría 7: «Espera un momento» nunca salía).
        if askAlways, lock.current != nil { return .busy }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }
        let cabinet = root

        let result = await service.lookup(book)
        // Mientras buscaba abriste otro Gabinete o el libro ya no está (auditoría 9, M3): no escribo
        // nada, ni «por revisar» ni «por buscar», en el Gabinete de ahora.
        guard stillHere(bookID, in: cabinet) else { return nil }
        // Empezó un trabajo mientras buscaba: tampoco dejo lo encontrado.
        if askAlways, lock.current != nil { return .busy }
        if result.decision == .unreachable {
            setPending(bookID, true)
            return .unreachable
        }
        // Un registro que ya deshiciste en este libro no se vuelve a poner solo: va a «Por revisar».
        if result.decision == .apply, !askAlways, let best = result.candidates.first,
           AutoFill.allowsAutoApply(best, declined: declined[bookID] ?? []) {
            var cover: Data?
            if coverURL(for: book) == nil { cover = await service.cover(for: best, language: book.language, title: book.title) }
            guard stillHere(bookID, in: cabinet) else { return nil }
            // Pudo cambiar mientras se buscaba (lo editaste): se completa lo más reciente.
            let current = self.book(id: bookID) ?? book
            let completed = rules.apply(to: MetadataMatcher.fillMissing(current, from: best))
            do {
                try update(completed, cover: cover)
                recordFilled(before: current, after: completed, from: best, addedCover: cover != nil)
            } catch LibraryError.busy {
                // Mientras muevo el Gabinete no se guarda (auditoría 5): la búsqueda no se pierde,
                // se queda pendiente y se repite cuando termine (`releaseLock`). Se dice «ocupado»,
                // no «sin conexión» (auditoría 6).
                setPending(bookID, true)
                return .busy
            } catch {
                // No se pudo guardar: lo encontrado espera en «Por revisar» en vez de perderse.
                setPending(bookID, false)
                setReview(bookID, candidates: result.candidates)
                return .review
            }
            setPending(bookID, false)
            setReview(bookID, candidates: nil)
        } else {
            setPending(bookID, false)
            setReview(bookID, candidates: result.candidates)
        }
        return result.decision
    }

    /// ¿Sigue abierto el mismo Gabinete y está el libro? Lo que vuelve de internet se guarda solo así.
    func stillHere(_ bookID: UUID, in cabinet: URL) -> Bool {
        root == cabinet && book(id: bookID) != nil
    }

    /// Espera a que termine la búsqueda que ya corre de ese libro (la vuelta de lo pendiente o el
    /// lote), sin empezar otra (auditoría 8, B2). Si quien espera se va, deja de esperar.
    func waitUntilSearched(_ bookID: UUID) async {
        for await searching in $identifying.values where !searching.contains(bookID) { return }
    }

    /// «Buscar con otros datos»: otro título, autor o ISBN. Los candidatos
    /// reemplazan a los de «Por revisar» de ese libro.
    @discardableResult
    func search(title: String, author: String?, isbn: String?, for bookID: UUID) async -> MetadataService.Decision? {
        guard let book = book(id: bookID), !identifying.contains(bookID) else { return nil }
        if lock.current != nil { return .busy }
        identifying.insert(bookID)
        defer { identifying.remove(bookID) }
        let cabinet = root
        let result = await service.search(title: title, author: author, isbn: isbn, for: book)
        // Lo mismo que `identify` (auditoría 9, M3): otro Gabinete o el libro ya no está, no escribo.
        guard stillHere(bookID, in: cabinet) else { return nil }
        if lock.current != nil { return .busy }
        if result.decision != .unreachable { setReview(bookID, candidates: result.candidates) }
        return result.decision
    }

    /// Completa un candidato con su sinopsis (para la vista previa).
    func details(for candidate: MetadataCandidate, bookID: UUID) async -> MetadataCandidate {
        guard let book = book(id: bookID) else { return candidate }
        let cabinet = root
        let detailed = await service.withSummary(candidate, for: book)
        if stillHere(bookID, in: cabinet), detailed.summary != candidate.summary, var list = reviews[bookID],
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
        let cabinet = root
        let detailed = await service.withSummary(candidate, for: book)
        let cover: Data?
        switch pick {
        case .keep: cover = nil
        case .automatic: cover = await service.cover(for: detailed, language: book.language)
        case .url(let url): cover = await service.coverData(at: url)
        }
        guard stillHere(bookID, in: cabinet) else { throw LibraryError.bookNotFound }
        let current = self.book(id: bookID) ?? book
        try update(rules.apply(to: MetadataMatcher.replace(current, with: detailed)), cover: cover)
        setReview(bookID, candidates: nil)
        forgetFilled(bookID)
        // Lo elegiste tú: los registros que habías rechazado ya no cuentan.
        if declined[bookID] != nil {
            declined[bookID] = nil
            persistDeclined([bookID])
        }
    }

    // MARK: Portadas para elegir

    /// Portadas de internet para un candidato (las de sus ediciones primero).
    func coverOptions(for candidate: MetadataCandidate, bookID: UUID) async -> [URL] {
        let book = book(id: bookID)
        return await service.coverOptions(for: candidate, language: book?.language, title: candidate.title, limit: 8)
    }

    /// Portadas de internet para un libro: las de su obra si ya se conoce
    /// (openlibrary: en el catálogo), si no, las de lo que encuentre la búsqueda.
    /// Las que van bajando llegan a `found`, en su orden, sin esperar a las demás (auditoría 9, B2).
    func coverOptions(for bookID: UUID, found: ([URL]) -> Void) async {
        guard let book = book(id: bookID) else { return }
        var candidates: [MetadataCandidate] = []
        if let work = book.identifiers["openlibrary"] {
            candidates = [MetadataCandidate(id: "ol:/works/\(work)", source: .openLibrary, title: book.title,
                                            workKey: "/works/\(work)")]
        } else {
            candidates = Array(await service.lookup(book).candidates.prefix(Theme.Lists.coverSources))
        }
        var urls: [URL] = []
        for candidate in candidates {
            urls += await service.coverOptions(for: candidate, language: book.language, title: book.title, limit: 8)
        }
        // Sin repetir (auditoría 8): por dirección y, ya bajadas, por sus bytes; ni la que ya tiene.
        // El tope de 12 va después de quitar las repetidas (auditoría 9, B2), así que bajo más.
        let wanted = Array(CoverDedupe.distinct(urls).prefix(Theme.Lists.coverDownloads))
        let current = coverURL(for: book).flatMap { try? Data(contentsOf: $0) }
        var collector = CoverDedupe.Collector(limit: Theme.Lists.coverOptions, current: current)
        let service = service
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (rank, url) in wanted.enumerated() {
                group.addTask { (rank, await service.coverData(at: url).flatMap { CoverImaging.jpeg(from: $0) }) }
            }
            // Cada una que baja se enseña ya, sin esperar a las demás, y se guarda para no bajarla
            // otra vez al dibujarla ni al elegirla.
            for await (rank, data) in group {
                let url = wanted[rank]
                if collector.accept(url, data, rank: rank), let data {
                    CoverImaging.remember(data, for: url)
                    found(collector.accepted.map(\.url))
                }
                if collector.isFull {
                    group.cancelAll()
                    break
                }
            }
        }
    }

    /// Cambia la portada por la elegida en la cuadrícula.
    func setCover(_ url: URL, for bookID: UUID) async throws {
        // La que ya bajó la cuadrícula no se baja otra vez.
        let remembered = CoverImaging.remembered(url)
        let cabinet = root
        guard let data = remembered != nil ? remembered : await service.coverData(at: url) else { throw LibraryError.coverUnavailable }
        guard stillHere(bookID, in: cabinet), let book = book(id: bookID) else { throw LibraryError.bookNotFound }
        try update(book, cover: data)
    }

    // MARK: Reglas

    func saveRules(_ new: MetadataRules) {
        let before = Self.ruleTable(rules), after = Self.ruleTable(new)
        let changed = Set(before.keys).union(after.keys).filter { before[$0] != after[$0] }
        rules = new
        persistRules(changed)
    }

    private func persistRules(_ changed: some Sequence<String>) {
        rules = Self.rules(from: persist(Self.ruleTable(rules), keys: changed, to: rulesURL,
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
        // Toda la biblioteca a la vez: no mientras corre otro trabajo así (auditoría 5).
        guard lock.current == nil else { return changed }
        for book in books {
            let mapped = rules.apply(to: book)
            if mapped != book, (try? update(mapped)) != nil { changed += 1 }
        }
        return changed
    }

    // MARK: Estantes (CB-1)

    /// Guarda un estante nuevo o los cambios de uno que ya existe.
    func saveShelf(_ shelf: SavedShelf) {
        var table = Self.shelfTable(shelves)
        table[shelf.id] = shelf
        shelves = Self.ordered(table)
        persistShelves([shelf.id])
    }

    func removeShelf(id: UUID) {
        var table = Self.shelfTable(shelves)
        table[id] = nil
        shelves = Self.ordered(table)
        persistShelves([id])
    }

    private func persistShelves(_ changed: [UUID]) {
        shelves = Self.ordered(persist(Self.shelfTable(shelves), keys: changed, to: shelvesURL,
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
        /// Cómo dejó este cambio cada libro de `originals` (mismo orden): deshacer regresa solo lo
        /// que cambió, sobre el libro de ahora (auditoría 6).
        var changed: [Book] = []
        var rulesBefore: MetadataRules
        /// Cómo dejó las reglas (auditoría 7, M5): deshacer quita o regresa solo las que tocó.
        var rulesAfter: MetadataRules
        var failed: [String] = []
        /// Por qué no cambié nada: otro trabajo de toda la biblioteca corre (auditoría 5).
        var refused: String?
    }

    /// Renombra o fusiona un autor, una serie o una etiqueta en todos sus libros. Con autores y
    /// etiquetas, también deja la regla para lo que llegue después (los libros que importes).
    @discardableResult
    func rename(_ rename: CatalogRename) -> CatalogChange {
        var change = CatalogChange(rulesBefore: rules, rulesAfter: rules)
        // Cambia muchos libros a la vez: no mientras ordeno, muevo o traigo de Calibre (auditoría 5).
        if let current = lock.current {
            change.refused = current.reason
            return change
        }
        for book in books where rename.touches(book) {
            do {
                change.changed.append(try update(rename.apply(to: book)))
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
        change.rulesAfter = learned
        return change
    }

    /// Los tomos de una serie como 1, 2, 3… en el orden que ya tenían.
    @discardableResult
    func renumber(series: String) -> CatalogChange {
        var change = CatalogChange(rulesBefore: rules, rulesAfter: rules)
        if let current = lock.current {
            change.refused = current.reason
            return change
        }
        let tomes = books.filter { $0.series == series }
        for renumbered in CatalogRename.renumber(tomes) {
            guard let original = book(id: renumbered.id) else { continue }
            do {
                change.changed.append(try update(renumbered))
                change.originals.append(original)
            } catch {
                change.failed.append(original.title)
            }
        }
        return change
    }

    /// Deshace un `rename` o `renumber`: los libros como estaban y las reglas de antes. Nunca a
    /// medias (auditoría 6, M3): si otro trabajo de toda la biblioteca corre, no toco nada y
    /// devuelvo por qué (`refused`). Solo regresan los datos que ese cambio tocó, sobre el libro de
    /// ahora: lo que cambiaste después se queda. Y de las reglas, solo las que ese cambio añadió o
    /// cambió y siguen como las dejó (auditoría 7, M5). Devuelve lo que hizo, como otro cambio:
    /// deshacerlo es rehacer (⌘⇧Z, auditoría 7, B3).
    @discardableResult
    func restore(_ change: CatalogChange) -> CatalogChange {
        var undone = CatalogChange(rulesBefore: rules, rulesAfter: rules)
        if let current = lock.current {
            undone.refused = current.reason
            return undone
        }
        for (original, changed) in zip(change.originals, change.changed) {
            guard let current = current(original.id) else { continue }
            let reverted = Book.revertingEdits(to: original, from: changed, onto: current)
            guard reverted != current, let saved = try? update(reverted) else { continue }
            undone.originals.append(current)
            undone.changed.append(saved)
        }
        let rulesNow = rules.undoing(from: change.rulesBefore, after: change.rulesAfter)
        if rulesNow != rules { saveRules(rulesNow) }
        undone.rulesAfter = rulesNow
        return undone
    }

    /// Deshace (o rehace) `change` en cuanto la biblioteca esté libre, de una vez: si ahora corre
    /// otro trabajo, te digo que lo haré al terminar y espero su turno (auditoría 7, B3). Así ⌘Z
    /// no se vuelve a anotar como algo nuevo, que borraba lo que podías rehacer.
    func restoreWhenFree(_ change: CatalogChange, named name: String) -> PendingRestore {
        let job = PendingRestore()
        let first = restore(change)
        guard let refused = first.refused else {
            job.done = first
            return job
        }
        explain("Todavía no deshice «\(name.isolated)»", refused + " Lo deshago yo en cuanto termine.")
        Task { [weak self] in
            while let self, !job.cancelled {
                guard self.lock.current != nil else {
                    job.done = self.restore(change)
                    return
                }
                await withCheckedContinuation { self.lockWaiters.append($0) }
            }
        }
        return job
    }

    /// Un deshacer que espera a que termine otro trabajo: rehacer antes de que corra lo cancela.
    final class PendingRestore {
        var done: CatalogChange?
        var cancelled = false

        /// Lo cancela si todavía no corrió. Devuelve true si lo canceló.
        func cancel() -> Bool {
            guard done == nil else { return false }
            cancelled = true
            return true
        }
    }

    // MARK: Lo que se completó solo

    private func recordFilled(before: Book, after: Book, from candidate: MetadataCandidate, addedCover: Bool) {
        var changes = FilledField.allCases.compactMap { field -> FilledChange? in
            guard field != .cover else { return nil }
            let old = field.value(in: before), new = field.value(in: after)
            return old == new ? nil : FilledChange(field: field, old: old, new: new)
        }
        if addedCover { changes.append(FilledChange(field: .cover, old: nil, new: "Nueva")) }
        guard !changes.isEmpty else { return }
        filled[before.id] = FilledRecord(date: Date(), changes: changes,
                                         identifiers: AutoFill.identifierChanges(from: before, to: after),
                                         record: AutoFill.recordKeys(candidate),
                                         coverHash: addedCover ? coverURL(for: after).flatMap { try? Self.sha256(of: $0) } : nil)
        persistFilled([before.id])
    }

    /// Deshace un dato que se completó solo. Si lo cambiaste después, se respeta lo tuyo. El
    /// registro de internet también se quita y se recuerda: no vuelve a ponerse solo (auditoría 1).
    func undoFilled(_ field: FilledField, for bookID: UUID) throws {
        guard var record = filled[bookID], let change = record.changes.first(where: { $0.field == field }),
              var book = book(id: bookID) else { return }
        // Antes de quitar la portada (auditoría 6, B4): se borraba y luego `update` fallaba por ocupado.
        try ensureCanEdit()
        AutoFill.undo(record.identifiers ?? [], in: &book)
        if field == .cover {
            // Solo la portada que puse yo: si la cambiaste después, la tuya se queda.
            if let url = coverURL(for: book), Self.isStillFilledCover(url, record: record) {
                try FileManager.default.removeItem(at: url)
                CoverImaging.forget(url)
                incompleteCache = nil
            }
        } else if field.value(in: book) == change.new {
            field.restore(change.old, in: &book)
        }
        try update(book)
        if let keys = record.record, !keys.isEmpty {
            declined[bookID, default: []].formUnion(keys)
            persistDeclined([bookID])
        }
        record.changes.removeAll { $0.field == field }
        filled[bookID] = record.changes.isEmpty ? nil : record
        persistFilled([bookID])
    }

    /// Deshace todo lo completado de un libro; si un dato falla, sigue con los demás y avisa al final.
    /// ¿La portada sigue siendo la que se completó sola? Por su huella; en lo guardado antes
    /// (sin huella), si no se cambió después de completarla.
    private static func isStillFilledCover(_ url: URL, record: FilledRecord) -> Bool {
        if let expected = record.coverHash { return (try? sha256(of: url)) == expected }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return modified.map { $0 <= record.date.addingTimeInterval(filledCoverSlack) } ?? true
    }

    /// Lo que tarda en escribirse la portada después de anotarla (para lo guardado sin huella).
    private static let filledCoverSlack: TimeInterval = 60

    func undoAllFilled(for bookID: UUID) throws {
        var firstError: Error?
        for change in filled[bookID]?.changes ?? [] {
            do { try undoFilled(change.field, for: bookID) } catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
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

    // MARK: Por revisar en lote (UX-5)

    /// Lo que hace falta para deshacer un lote de «Por revisar».
    struct ReviewUndo {
        /// Las opciones que tenía cada libro en «Por revisar».
        let reviews: [UUID: [MetadataCandidate]]
        /// Lo que ya se había completado solo antes, para dejarlo como estaba.
        let filledBefore: [UUID: FilledRecord]
        /// Los que cambiaron en este lote: se deshacen dato por dato.
        let completed: [UUID]
        /// Lo que este lote anotó en «Lo que completé solo», libro por libro: deshacer solo
        /// quita eso (si después se completó otra cosa, esa no se toca).
        var recorded: [UUID: FilledRecord] = [:]
    }

    /// Un lote que no se pudo deshacer completo: qué libros quedaron como estaban.
    struct UndoFailed: LocalizedError {
        let titles: [String]
        var errorDescription: String? {
            "No pude deshacer \(titles.count.counted("libro", "libros")): \(titles.map { "«\($0.isolated)»" }.joined(separator: ", ")). "
                + "Los demás sí regresaron a «Por revisar»; vuelve a intentarlo con esos."
        }
    }

    /// «Completar los muy probables»: a cada libro se le llena lo que le falta con su mejor
    /// opción (y la portada si no tenía), como cuando se completa solo, y sale de «Por revisar».
    /// Lo que ya tenía no cambia; queda en «Lo que completé solo» para deshacerlo dato por dato.
    func completeSafeReviews(_ ids: [UUID]) async -> ReviewUndo {
        var saved: [UUID: [MetadataCandidate]] = [:], before: [UUID: FilledRecord] = [:], completed: [UUID] = []
        var recorded: [UUID: FilledRecord] = [:]
        for id in ids {
            // Lo que deshiciste de un lote anterior no se vuelve a poner en lote; eligiéndolo tú, sí.
            guard let candidates = reviews[id], MetadataMatcher.isSafeSuggestion(candidates),
                  let best = candidates.first, AutoFill.allowsAutoApply(best, declined: declined[id] ?? []),
                  let book = book(id: id) else { continue }
            var cover: Data?
            if coverURL(for: book) == nil { cover = await service.cover(for: best, language: book.language, title: book.title) }
            // Pudo cambiar mientras se bajaba la portada: se completa lo más reciente.
            let current = self.book(id: id) ?? book
            let filledIn = rules.apply(to: MetadataMatcher.fillMissing(current, from: best))
            saved[id] = candidates
            if let record = filled[id] { before[id] = record }
            if filledIn != current || cover != nil {
                do {
                    try update(filledIn, cover: cover)
                    recordFilled(before: current, after: filledIn, from: best, addedCover: cover != nil)
                    completed.append(id)
                    if let record = filled[id] { recorded[id] = record }
                } catch {
                    // No se guardó (p. ej. mientras muevo el Gabinete): se queda en «Por revisar» (auditoría 5).
                    saved[id] = nil
                    continue
                }
            }
            setReview(id, candidates: nil)
        }
        return ReviewUndo(reviews: saved, filledBefore: before, completed: completed, recorded: recorded)
    }

    /// «Mantener los datos» de varios: salen de «Por revisar» sin cambiar nada.
    func dismissReviews(_ ids: [UUID]) -> ReviewUndo {
        var saved: [UUID: [MetadataCandidate]] = [:]
        for id in ids {
            guard let candidates = reviews[id] else { continue }
            saved[id] = candidates
            setReview(id, candidates: nil)
        }
        return ReviewUndo(reviews: saved, filledBefore: [:], completed: [])
    }

    /// Deshace un lote: lo completado vuelve a como estaba (si lo cambiaste después, se respeta
    /// lo tuyo) y cada libro regresa a «Por revisar» con sus opciones.
    /// Un error en un libro no detiene a los demás (auditoría de medios): se sigue con todos y
    /// al final se dice cuáles no se pudieron. Solo se deshace lo que anotó este lote.
    func undo(_ batch: ReviewUndo) throws {
        var failed: [String] = []
        for id in batch.completed {
            // Lo que completó este lote, si sigue ahí: si después se completó otra vez, eso no se toca.
            let mine = batch.recorded[id]
            guard mine == nil || filled[id]?.date == mine?.date else { continue }
            let ours = mine.map { Set($0.changes.map(\.field)) }
            let fields = (filled[id]?.changes ?? []).map(\.field).filter { ours?.contains($0) ?? true }
            var undone = true
            for field in fields {
                do { try undoFilled(field, for: id) } catch { undone = false }
            }
            guard undone else {
                failed.append(book(id: id)?.title ?? MetadataCleaner.untitled)
                continue
            }
            if let record = batch.filledBefore[id] {
                filled[id] = record
                persistFilled([id])
            }
        }
        for (id, candidates) in batch.reviews where book(id: id) != nil {
            setReview(id, candidates: candidates)
        }
        if !failed.isEmpty { throw UndoFailed(titles: failed) }
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
        notDuplicates.formUnion(added)
        persistNotDuplicates(added)
    }

    private func persistNotDuplicates(_ added: Set<DuplicateFinder.Pair>) {
        let table = Dictionary(uniqueKeysWithValues: notDuplicates.map { ($0, true) })
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
        // Mientras ordeno, muevo o traigo de Calibre, no junto: lo haría sobre una lista vieja (auditoría 4).
        try ensureIdle()
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
                guard FileManager.default.fileExists(atPath: source.path) else {
                    // En iCloud sin bajar no es «no está»: se pide y se espera, porque luego su
                    // carpeta se tira y el archivo se perdería (auditoría 1).
                    if CloudFile.isPlaceholder(source) {
                        CloudFile.requestDownload(source)
                        throw LibraryError.stillDownloading(title: other.title)
                    }
                    continue
                }
                let format = (name as NSString).pathExtension.uppercased()
                if formats.contains(format) {
                    leftovers.append(source)
                } else {
                    let target = CalibreLayout.fileName(title: keep.title, authors: keep.authors,
                                                        fileExtension: (name as NSString).pathExtension)
                    guard !CloudFile.isTaken(keepFolder.appendingPathComponent(target)) else {
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

        // 3. Ya juntos: las lápidas de todos primero, de una vez. Dicen en quién se juntó cada uno
        // (tus otros dispositivos le pasan sus subrayados). Si tu registro no se puede escribir
        // (sigue en iCloud sin bajar), no se movió nada más: ni posición, ni subrayados, ni
        // marcadores, nada va a la Papelera y los libros siguen en el catálogo (auditorías 2 y 3).
        let positions = [keepID] + others.map(\.id)
        let spots = positions.map { id in position(for: id).map { DuplicateFinder.Spot(fraction: $0.fraction, updatedAt: $0.updatedAt) } }
        let furthest = DuplicateFinder.furthest(spots).flatMap { $0 > 0 ? position(for: positions[$0]) : nil }
        do {
            try recordNow(others.flatMap { other in
                [Book.deletion(id: other.id, clock: clock),
                 Change(hlc: clock.tick(), entity: .book, entityID: other.id, field: Self.mergedIntoField,
                        value: .string(keepID.uuidString))]
            })
        } catch {
            books = state.books()
            throw error
        }
        // Lo de los otros pasa al que se queda y lo que sobra va a la Papelera.
        // Donde ibas: la más avanzada de todos (si era la de otro, solo su avance: su CFI es de
        // otro archivo).
        if let spot = furthest {
            savePosition(ReadingPosition(cfi: nil, fraction: spot.fraction, excerpt: spot.excerpt), for: keepID)
        }
        for other in others {
            // Subrayados: pasan al que se queda y se vuelven a anclar por su cita (el archivo es otro).
            for var annotation in AnnotationStore.shared.annotations(forBook: other.id) where annotation.bookID == other.id {
                annotation.bookID = keepID
                annotation.cfi = nil
                try? AnnotationStore.shared.save(annotation)
                report.movedHighlights += 1
            }
            // Marcadores: su CFI es de otro archivo; pasan con su avance y el lector abre a esa altura.
            for bookmark in bookmarks(for: other.id) {
                removeBookmark(id: bookmark.id)
                addBookmark(bookmark.moved(to: keepID))
            }
            setReview(other.id, candidates: nil)
        }
        for file in leftovers where (try? Self.discard(file)) != nil { report.trashed += 1 }
        // Lo que queda de sus carpetas (portada y metadata.opf) también va a la Papelera. Si queda
        // algo más (un archivo que no se movió), la carpeta se queda y «Ordenar» la enseña.
        for folder in others.compactMap({ $0.folderPath.map { root.appendingPathComponent($0, isDirectory: true) } })
        where FileManager.default.fileExists(atPath: folder.path) && !FolderMove.sameIgnoringCase(folder, keepFolder)
            && DuplicateFinder.canDiscardFolder(containing: (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? ["?"]) {
            try? Self.discard(folder)
            removeIfEmpty(folder.deletingLastPathComponent())
        }
        books = state.books()
        return report
    }

    static let mergedIntoField = "merged_into"

    /// Los libros que se juntaron en este, aquí o en otro dispositivo, también en cadena
    /// (X en Y y luego Y en este).
    func booksMerged(into id: UUID) -> [UUID] {
        DuplicateFinder.absorbed(into: id, table: mergedInto)
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
        // Una sola fila de consultas (auditoría 8, M5): la vuelta de lo pendiente se detiene y
        // sigue al terminar el lote. Antes las dos preguntaban a la vez, a veces por el mismo libro.
        stopPendingLookups()
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
            guard let self, self.batchToken == token else { return }
            self.batchTask = nil
            self.batchToken = nil
            // Lo pendiente que esperaba al lote, ahora (si hay internet: si no, el lote ya lo dejó pendiente).
            if self.batch?.stopped != true, unreachableInARow < BatchLookup.unreachableLimit, self.lock.current == nil {
                await self.retryPendingLookups()
            }
        }
    }

    /// Detiene la búsqueda en lote (tu botón «Detener»); lo ya completado se queda. Lo que esperaba
    /// conexión no se queda sin buscar hasta volver a abrir la app (auditoría 9, B7): la vuelta de lo
    /// pendiente, que el lote había pausado, sigue en cuanto no hay otro trabajo (si lo hay, al
    /// terminar, `releaseLock`).
    func stopBatch() {
        haltBatch()
        if lock.current == nil, !pendingLookup.isEmpty {
            Task { [weak self] in await self?.retryPendingLookups() }
        }
    }

    /// Detiene el lote y la vuelta de lo pendiente, sin retomar nada: al mover el Gabinete o abrir otro.
    private func haltBatch() {
        batchTask?.cancel()
        batchTask = nil
        batchToken = nil
        batch?.stopped = true
        stopPendingLookups()
    }

    /// Detiene la vuelta de lo pendiente (al mover el Gabinete o cambiar de biblioteca).
    private func stopPendingLookups() {
        lookupRetry?.cancel()
        lookupRetry = nil
        lookupRetryToken = nil
    }

    /// Quita el aviso del resultado.
    func clearBatch() {
        guard batchTask == nil else { return }
        batch = nil
    }

    /// Vuelve a buscar los libros que se quedaron sin buscar por falta de internet. Una vuelta a la
    /// vez (si ya hay una, espera a esa), con la misma pausa entre libros que la búsqueda en lote,
    /// y se puede detener (auditoría 7, M4).
    func retryPendingLookups() async {
        if let lookupRetry { return await lookupRetry.value }
        guard !pendingLookup.isEmpty, batchTask == nil else { return }
        let token = UUID()
        lookupRetryToken = token
        let task = Task { [weak self] in
            guard let ids = self?.pendingLookup.sorted(by: { $0.uuidString < $1.uuidString }) else { return }
            var asked = false
            for id in ids {
                guard let self, !Task.isCancelled, self.lookupRetryToken == token else { break }
                guard self.pendingLookup.contains(id), self.book(id: id) != nil else { continue }
                if asked {
                    try? await Task.sleep(for: BatchLookup.pause)
                    guard !Task.isCancelled, self.lookupRetryToken == token else { break }
                }
                asked = true
                let decision = await self.identify(id)
                if decision == .unreachable || decision == .busy { break }
            }
            if self?.lookupRetryToken == token {
                self?.lookupRetry = nil
                self?.lookupRetryToken = nil
            }
        }
        lookupRetry = task
        await task.value
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

    /// Los registros de internet que deshiciste en cada libro: ya no se aplican solos.
    private var declinedURL: URL {
        root.appendingPathComponent(".lectora/rechazados.json")
    }

    private func setReview(_ bookID: UUID, candidates: [MetadataCandidate]?) {
        reviews[bookID] = candidates
        persistReviews([bookID])
    }

    private func persistReviews(_ keys: [UUID]) {
        reviews = persist(reviews, keys: keys, to: reviewsURL,
                          read: { try? JSONDecoder().decode([UUID: [MetadataCandidate]].self, from: $0) },
                          write: { try? JSONEncoder().encode($0) })
    }

    private func persistFilled(_ keys: [UUID]) {
        filled = persist(filled, keys: keys, to: filledURL,
                         read: { try? JSONDecoder().decode([UUID: FilledRecord].self, from: $0) },
                         write: { try? JSONEncoder().encode($0) })
    }

    private func persistDeclined(_ keys: [UUID]) {
        declined = persist(declined, keys: keys, to: declinedURL,
                           read: { try? JSONDecoder().decode([UUID: Set<String>].self, from: $0) },
                           write: { try? JSONEncoder().encode($0) })
    }

    private func setPending(_ bookID: UUID, _ pending: Bool) {
        guard pendingLookup.contains(bookID) != pending else { return }
        if pending { pendingLookup.insert(bookID) } else { pendingLookup.remove(bookID) }
        persistPending([bookID])
    }

    private func persistPending(_ keys: [UUID]) {
        let table = Dictionary(uniqueKeysWithValues: pendingLookup.map { ($0, true) })
        pendingLookup = Set(persist(table, keys: keys, to: pendingURL,
                                    read: { (try? JSONDecoder().decode(Set<UUID>.self, from: $0)).map { Dictionary(uniqueKeysWithValues: $0.map { ($0, true) }) } },
                                    write: { try? JSONEncoder().encode(Set($0.keys)) }).keys)
    }

    /// RB-3: escribe solo las claves que cambiaron aquí, encima de lo que ya hay en el
    /// disco. Lo que otro dispositivo guardó mientras tanto (por iCloud) no se pisa. Si el
    /// archivo sigue en iCloud sin bajar o no se pudo leer, no se escribe (auditoría 1): el
    /// cambio se guarda en el dispositivo y se reintenta solo en cuanto baja, al volver a la
    /// app o al abrirla otra vez (auditoría 2).
    private func persist<K: Codable & Hashable, V: Codable>(_ mine: [K: V], keys: some Sequence<K>, to url: URL,
                                                           read: (Data) -> [K: V]?, write: ([K: V]) -> Data?) -> [K: V] {
        let result = SideFile.persist(mine, keys: keys, at: url, pending: pendingWrites, decode: read, encode: write)
        if !result.written {
            keepRetrying()
            // Dañado (no es esperar a iCloud): te lo digo una vez, no en cada intento.
            if SideFile.isDamaged(url, decode: read), damagedNoticed.insert(url.lastPathComponent).inserted {
                noticeTitle = Self.damagedNoticeTitle
                notice = SideFile.damagedNotice(url.lastPathComponent)
            }
        }
        return result.table
    }

    /// Cómo reintentar cada archivo de `.lectora/` (por su nombre).
    private var sideFileRetries: [String: () -> Void] {
        [reviewsURL.lastPathComponent: { [weak self] in self?.persistReviews([]) },
         filledURL.lastPathComponent: { [weak self] in self?.persistFilled([]) },
         declinedURL.lastPathComponent: { [weak self] in self?.persistDeclined([]) },
         pendingURL.lastPathComponent: { [weak self] in self?.persistPending([]) },
         rulesURL.lastPathComponent: { [weak self] in self?.persistRules([]) },
         shelvesURL.lastPathComponent: { [weak self] in self?.persistShelves([]) },
         notDuplicatesURL.lastPathComponent: { [weak self] in self?.persistNotDuplicates([]) },
         Self.pendingChangesName: { [weak self] in self?.writePendingChanges() }]
    }

    /// Vuelve a intentar lo que esperaba a iCloud (también lo de antes de cerrar la app).
    private func retryWaitingFiles() {
        let retries = sideFileRetries
        for name in pendingWrites.names { retries[name]?() }
    }

    /// Queda algo de la biblioteca esperando a iCloud (las sesiones esperan aparte).
    private var hasWaitingFiles: Bool {
        let retries = sideFileRetries
        return pendingWrites.names.contains { retries[$0] != nil }
    }

    /// Mientras quede algo pendiente, reintenta cada poco (iCloud suele bajarlo en segundos).
    private func keepRetrying() {
        guard retryTask == nil else { return }
        let folder = root
        retryTask = Task { [weak self] in
            for _ in 0..<CloudFiles.waitAttempts {
                try? await Task.sleep(for: CloudFiles.settle)
                guard !Task.isCancelled, let self, self.root == folder, self.hasWaitingFiles else { break }
                self.retryWaitingFiles()
            }
            if !Task.isCancelled { self?.retryTask = nil }
        }
    }

    /// Lo del disco, salvo que aquí haya cambios que todavía no se pudieron escribir: esos mandan.
    private func settled(_ url: URL) -> Data? {
        pendingWrites.has(url.lastPathComponent) ? nil : try? Data(contentsOf: url)
    }

    private func loadReviews() {
        retryWaitingFiles()
        if let data = settled(reviewsURL),
           let saved = try? JSONDecoder().decode([UUID: [MetadataCandidate]].self, from: data) {
            reviews = books.isEmpty ? saved : saved.filter { book(id: $0.key) != nil }
        }
        if let data = settled(pendingURL), let saved = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            pendingLookup = books.isEmpty ? saved : saved.filter { book(id: $0) != nil }
        }
        if let data = settled(filledURL),
           let saved = try? JSONDecoder().decode([UUID: FilledRecord].self, from: data) {
            filled = books.isEmpty ? saved : saved.filter { book(id: $0.key) != nil }
        }
        if let data = settled(rulesURL), let saved = try? JSONDecoder().decode(MetadataRules.self, from: data) {
            rules = saved
        }
        if let data = settled(shelvesURL), let saved = try? JSONDecoder().decode([SavedShelf].self, from: data) {
            shelves = Self.ordered(Self.shelfTable(saved))
        }
        if let data = settled(declinedURL),
           let saved = try? JSONDecoder().decode([UUID: Set<String>].self, from: data) {
            declined = saved
        }
        if let data = settled(notDuplicatesURL),
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
        // Si tu registro sigue en iCloud sin bajar, la posición espera en el dispositivo (auditoría 2).
        appendOrKeep(changes)
        state.apply(changes)
        objectWillChange.send()
    }

    // MARK: Interno

    /// En `pendientes/`: cambios del catálogo que esperan a que tu registro baje de iCloud.
    static let pendingChangesName = "registro.json"

    /// Lo que espera, en memoria y en el dispositivo a la vez (auditoría 3): cada guardado solo
    /// agrega sus renglones al archivo pendiente. Antes se leía, decodificaba y reescribía todo lo
    /// pendiente en cada página asentada (cada vez más lento mientras iCloud no bajaba).
    private var pendingChanges: [Change] {
        if let pendingCache { return pendingCache }
        let saved = pendingWrites.lines(Self.pendingChangesName, as: Change.self)
        pendingCache = saved
        return saved
    }
    /// nil: todavía no se lee del dispositivo (al abrir otro Gabinete se vuelve a leer).
    private var pendingCache: [Change]?

    /// Agrega al registro. Si no se puede (tu registro sigue en iCloud sin bajar), los cambios
    /// esperan guardados en el dispositivo y se escriben en cuanto baja: nunca se pierden en
    /// silencio, aunque cierres la app (auditoría 2).
    private func appendOrKeep(_ changes: [Change]) {
        writePendingChanges()
        guard !pendingChanges.isEmpty || (try? appendToLog(changes)) == nil else { return }
        pendingCache = pendingChanges + changes
        pendingWrites.appendLines(changes, Self.pendingChangesName)
        keepRetrying()
    }

    /// Escribe en el registro lo que esperaba.
    private func writePendingChanges() {
        let waiting = pendingChanges
        guard !waiting.isEmpty, (try? appendToLog(waiting)) != nil else { return }
        pendingWrites.removeLines(Self.pendingChangesName)
        pendingCache = []
    }

    /// Agrega al registro ya, o falla: para lo que viene antes de tirar algo (la lápida al juntar).
    private func recordNow(_ changes: [Change]) throws {
        try appendToLog(changes)
        state.apply(changes)
        if changes.contains(where: { $0.field == Self.mergedIntoField }) { rebuildMergedInto() }
    }

    private func writeOPF(_ book: Book, hasCover: Bool) throws {
        guard let folder = book.folderPath else { return }
        let url = root.appendingPathComponent(folder).appendingPathComponent(CalibreLayout.opfFileName)
        try Data(CalibreOPF.write(book, hasCover: hasCover).utf8).write(to: url, options: .atomic)
    }

    private func record(_ book: Book) throws {
        // Solo los campos que cambiaron: una copia vieja de otro dispositivo no pisa lo demás (RB-3).
        let changes = book.changes(from: current(book.id), clock: clock)
        guard !changes.isEmpty else { return }
        try appendToLog(changes)
        state.apply(changes)
        // En «Ordenar» y al traer de Calibre los libros se arman al final, no uno por uno (auditoría 3).
        // Lo que tú cambias mientras tanto sí se ve ya: no parece que no se guardó (auditoría 4).
        if !deferringBooks.isActive || !bulkWriting { books = state.books() }
    }

    /// Cuántos trabajos piden armar `books` al final (auditoría 4, M4): el primero que termina no
    /// los arma mientras otro sigue.
    private var deferringBooks = DeferCount()
    /// Lo escribe el trabajo largo mismo («Ordenar», traer de Calibre), no tú.
    private var bulkWriting = false
    /// El índice del disco del trabajo largo en curso («Ordenar», traer de Calibre): tus cambios
    /// pasan por él, así el trabajo sabe de las carpetas que crean (auditoría 5).
    private var activeSpelling: SpellingIndex?

    private func deferBooks() { deferringBooks.begin() }

    /// Termina uno; con el último, los libros se arman una vez.
    private func resumeBooks() {
        if deferringBooks.end() { books = state.books() }
    }

    /// Lo que el trabajo largo escribe por su cuenta (sin armar los libros en cada uno).
    private func bulk<T>(_ body: () throws -> T) rethrows -> T {
        bulkWriting = true
        defer { bulkWriting = false }
        return try body()
    }

    /// El libro tal como quedó en el registro (también mientras `books` espera a armarse).
    private func current(_ id: UUID) -> Book? {
        guard deferringBooks.isActive else { return book(id: id) }
        guard !state.isDeleted(.book, id: id) else { return nil }
        return state.fields(of: .book, id: id).flatMap { Book(id: id, fields: $0) }
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
        // Con un id nuevo, lo que este aparato tenía tomado con el de antes se suelta (auditoría 3).
        if let previous = AnnotationStore.previousDeviceID {
            record(Self.jobBoard.release(claimsOf: previous, in: state, clock: clock))
            AnnotationStore.forgetPreviousDeviceID()
        }
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
        appendOrKeep(changes)
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
    /// Cuántos números de Calibre pruebo si la carpeta de un libro se ocupa mientras lo copio.
    static let placeAttempts = 3
    /// Lo que dice el resumen de un libro que no traje porque su carpeta se ocupó una y otra vez.
    static let calibreFolderTaken = "Mientras lo copiaba llegó de iCloud otra carpeta con ese nombre. No la toqué: vuelve a traerlo."

    /// Trae una biblioteca de Calibre: copia cada carpeta de libro tal cual
    /// (archivos, portada), conserva su número de Calibre si está libre, escribe
    /// su OPF al día y anota el libro y sus subrayados en tu Gabinete. La
    /// biblioteca de Calibre no se toca.
    func migrateFromCalibre(_ source: URL, plan: CalibreMigrationPlan,
                            annotations: AnnotationStore) async -> CalibreMigrationReport {
        var report = CalibreMigrationReport()
        // Con tu biblioteca a medio bajar de iCloud no traigo nada (auditoría 6): el plan saldría
        // de una lista incompleta y los números de Calibre chocarían con los que faltan.
        guard !waitingForCloud else {
            report.failed.append((title: "Tu biblioteca de Calibre", reason: EmptyCopy.addWhileDownloading))
            return report
        }
        // Un trabajo de toda la biblioteca a la vez (auditoría 4).
        guard lock.begin(.migrating) else {
            report.failed.append((title: "Tu biblioteca de Calibre", reason: busyReason ?? ""))
            return report
        }
        defer { releaseLock(.migrating) }
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        report.alreadyHere = plan.alreadyHere.count
        report.withoutFiles = plan.withoutFiles.map(\.book.title)
        progress = (0, plan.toImport.count)
        defer { progress = nil }

        var lastID = books.compactMap(\.calibreID).max() ?? 0
        // Un índice del disco para toda la migración y los libros se arman cada `tidyChunk`, no
        // en cada uno: con miles de libros, la app no se congela (auditoría 3).
        let spelling = SpellingIndex(root: root)
        activeSpelling = spelling
        defer { activeSpelling = nil }
        var usedIDs = Set(books.compactMap(\.calibreID))
        deferBooks()
        defer { resumeBooks() }
        for (index, entry) in plan.toImport.enumerated() {
            if index % Self.tidyChunk == Self.tidyChunk - 1 { books = state.books() }
            var book = rules.apply(to: entry.book)
            var calibreID = entry.book.calibreID ?? lastID + 1
            guard let preferred = entry.preferredFile else { continue }
            let fileName = (preferred as NSString).lastPathComponent
            let from = source.appendingPathComponent(entry.folder, isDirectory: true)
            let library = root
            // Con el nombre del disco: si ya hay una carpeta del autor con otras mayúsculas, el
            // libro entra a ella y el catálogo guarda la ruta real (auditoría 2).
            var folder = FolderMove.diskSpelling(of: entry.folder, in: root, index: spelling)
            var to = root.appendingPathComponent(folder, isDirectory: true)
            // Solo quito lo que puse yo (auditoría 9, M1): la carpeta del libro, una vez en su lugar.
            var placed = false
            do {
                // Si mientras copio llega de iCloud una carpeta con ese nombre (de otro aparato), no se
                // pisa ni se borra: el libro toma el siguiente número libre, hasta `placeAttempts` veces.
                for attempt in 1...Self.placeAttempts {
                    // Número libre en el catálogo y en el disco: otro dispositivo pudo usar esa carpeta.
                    while usedIDs.contains(calibreID) || CloudFile.isTaken(root.appendingPathComponent(folder)) {
                        lastID = max(lastID, usedIDs.max() ?? 0) + 1
                        calibreID = lastID
                        folder = FolderMove.diskSpelling(of: CalibreLayout.folder(title: book.title, authors: book.authors,
                                                                                  calibreID: calibreID), in: root, index: spelling)
                    }
                    lastID = max(lastID, calibreID)
                    to = root.appendingPathComponent(folder, isDirectory: true)
                    let target = to, author = (folder as NSString).deletingLastPathComponent
                    do {
                        book.fileHash = try await Task.detached(priority: .userInitiated) {
                            try FolderMove.createFolder(author, in: library)
                            try FolderMove.placeNew(target) { try FileManager.default.copyItem(at: from, to: $0) }
                            return try LibraryStore.sha256(of: target.appendingPathComponent(fileName))
                        }.value
                        placed = true
                        break
                    } catch FolderMove.MoveError.occupied where attempt < Self.placeAttempts {
                        spelling.forget(path: folder)
                        usedIDs.insert(calibreID)
                    }
                }
                spelling.forget(path: folder)
                usedIDs.insert(calibreID)
                book.calibreID = calibreID
                book.filePath = "\(folder)/\(fileName)"
                // Los demás formatos de Calibre también quedan en la ficha (CB-3).
                book.extraFiles = entry.formats.values.map { ($0 as NSString).lastPathComponent }
                    .filter { $0 != fileName }.sorted()
                let hasCover = FileManager.default.fileExists(atPath: to.appendingPathComponent(CalibreLayout.coverFileName).path)
                try writeOPF(book, hasCover: hasCover)
                try bulk { try record(book) }
                for highlight in entry.annotations {
                    // Solo cuenta lo que sí se guardó (auditoría 9, B9).
                    let saved = (try? annotations.save(Annotation(bookID: book.id, cfi: nil, quote: highlight.text, color: "pencil",
                                                                  note: highlight.note, createdAt: highlight.createdAt ?? Date(),
                                                                  source: "calibre"))) != nil
                    if saved { report.annotations += 1 }
                }
                report.imported += 1
            } catch {
                // Solo la carpeta que puse yo en su lugar; la de trabajo ya la quitó `placeNew`. Una
                // que llegó de otro aparato con ese nombre no es de esta corrida y se queda.
                if placed { try? FileManager.default.removeItem(at: to) }
                FolderMove.removeIfEmpty(to.deletingLastPathComponent(), index: spelling)
                spelling.forget(path: folder)
                let reason = (error as? FolderMove.MoveError) == .occupied ? Self.calibreFolderTaken : error.localizedDescription
                report.failed.append((entry.book.title, reason))
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
