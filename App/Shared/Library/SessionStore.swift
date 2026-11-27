import Foundation
import LectoraCore

/// Ajustes de las sesiones de lectura.
enum SessionKeys {
    /// Mostrar el contador de palabras en el lector.
    static let counter = "sesiones.contador"
    /// Mostrar el resumen al cerrar el libro.
    static let summary = "sesiones.resumen"
    /// Sesiones que aún no se pudieron escribir, de antes de que cada Gabinete tuviera las suyas
    /// (auditoría 2): solo se pasan al Gabinete que tiene esos libros.
    static let legacyUnsaved = "sesiones.pendientes"
}

/// Las sesiones de lectura del Gabinete (`Biblioteca/.lectora/sesiones/`), de
/// todos tus dispositivos. El lector agrega una al cerrar el libro.
@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var sessions: [ReadingSession] = []
    /// La sesión que acaba de terminar, para el resumen al cerrar el libro.
    @Published var justFinished: ReadingSession?
    private var log: SessionLog
    /// Lo pendiente del Gabinete de este diario (auditoría 2): nunca se escribe en el de otro.
    private var pending: PendingWrites
    private var retryTask: Task<Void, Never>?
    /// En `pendientes/<gabinete>/`.
    static let pendingName = "sesiones.json"

    /// Una sesión de menos de esto (leyendo de verdad) no se guarda.
    static let minimumReading: TimeInterval = 60
    /// El resumen al cerrar solo aparece si leíste al menos esto.
    static let minimumForSummary: TimeInterval = 120

    init(root: URL? = nil) {
        let root = root ?? LibraryStore.shared.root
        log = SessionLog(directory: Self.folder(in: root), device: AnnotationStore.deviceID)
        pending = PendingWrites.forCabinet(root.deletingLastPathComponent())
        reload()
    }

    nonisolated static func folder(in root: URL) -> URL {
        root.appendingPathComponent(".lectora/sesiones", isDirectory: true)
    }

    /// Cambió la carpeta del Gabinete.
    func use(root: URL) {
        let folder = Self.folder(in: root)
        guard folder != log.directory else { return }
        log = SessionLog(directory: folder, device: AnnotationStore.deviceID)
        pending = PendingWrites.forCabinet(root.deletingLastPathComponent())
        retryTask?.cancel()
        retryTask = nil
        reload()
    }

    func reload() {
        adoptLegacyUnsaved()
        writeUnsaved()
        let saved = log.readAll()
        let ids = Set(saved.map(\.id))
        // Lo que aún no se escribe también se ve en el diario.
        sessions = (saved + unsaved.filter { !ids.contains($0.id) }).sorted { $0.start < $1.start }
    }

    /// Sesiones que esperan a que iCloud baje tu registro (auditoría 1): se guardan en el
    /// dispositivo, junto al Gabinete al que pertenecen, no se pierden al cerrar la app y se
    /// escriben en cuanto el registro está en el dispositivo (auditoría 2).
    private var unsaved: [ReadingSession] {
        get { pending.value(Self.pendingName, as: [ReadingSession].self) ?? [] }
        set { pending.set(newValue.isEmpty ? nil : newValue, Self.pendingName) }
    }

    /// Las pendientes de antes (una sola lista para todos los Gabinetes) pasan a este solo si
    /// son de libros que están en él; las demás esperan a que abras su Gabinete.
    private func adoptLegacyUnsaved() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: SessionKeys.legacyUnsaved),
              let legacy = try? JSONDecoder().decode([ReadingSession].self, from: data) else { return }
        let library = LibraryStore.shared
        guard Self.folder(in: library.root) == log.directory else { return }
        let mine = legacy.filter { library.book(id: $0.bookID) != nil }
        guard !mine.isEmpty else { return }
        unsaved += mine
        let rest = legacy.filter { library.book(id: $0.bookID) == nil }
        if rest.isEmpty {
            defaults.removeObject(forKey: SessionKeys.legacyUnsaved)
        } else {
            defaults.set(try? JSONEncoder().encode(rest), forKey: SessionKeys.legacyUnsaved)
        }
    }

    /// Escribe ya lo que esperaba a iCloud (antes de mover el Gabinete, auditoría 3).
    func writePending() {
        writeUnsaved()
    }

    /// Escribe lo pendiente. Devuelve si quedó todo escrito; si no, reintenta cada poco.
    @discardableResult
    private func writeUnsaved() -> Bool {
        let waiting = unsaved
        guard !waiting.isEmpty else { return true }
        guard (try? log.append(waiting)) != nil else {
            keepRetrying()
            return false
        }
        unsaved = []
        return true
    }

    /// Mientras iCloud baja tu registro, vuelve a intentarlo cada poco.
    private func keepRetrying() {
        guard retryTask == nil else { return }
        let folder = log.directory
        retryTask = Task { [weak self] in
            for _ in 0..<CloudFiles.waitAttempts {
                try? await Task.sleep(for: CloudFiles.settle)
                guard !Task.isCancelled, let self, self.log.directory == folder else { break }
                if self.writeUnsaved() { break }
            }
            if !Task.isCancelled { self?.retryTask = nil }
        }
    }

    /// Al volver a la app: pide a iCloud las sesiones de tus otros dispositivos y vuelve a leer.
    func refreshFromCloud() {
        let folder = log.directory
        Task.detached(priority: .utility) { [weak self] in
            CloudFiles.requestSmallFiles(in: folder)
            try? await Task.sleep(for: CloudFiles.settle)
            await self?.reload()
        }
    }

    /// Guarda una sesión terminada (si se leyó lo suficiente).
    func record(_ session: ReadingSession) {
        guard session.readingSeconds >= Self.minimumReading else { return }
        // Si tu registro sigue en iCloud sin bajar, la sesión espera y se escribe después:
        // nunca se crea un registro nuevo encima del tuyo (auditoría 1).
        unsaved.append(session)
        writeUnsaved()
        sessions.append(session)
        let wantsSummary = UserDefaults.standard.object(forKey: SessionKeys.summary) as? Bool ?? true
        if wantsSummary, session.readingSeconds >= Self.minimumForSummary { justFinished = session }
    }

    /// Guarda sin mostrar el resumen (sesiones de muestra para las capturas).
    func add(_ session: ReadingSession) {
        guard (try? log.append(session)) != nil else { return }
        sessions.append(session)
        sessions.sort { $0.start < $1.start }
    }

    /// La semana (lunes a domingo) de `date`, con sus días.
    func week(of date: Date = Date()) -> (period: ReadingPeriod, days: [ReadingDay]) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return (all, []) }
        let period = all.between(interval.start, interval.end)
        return (period, period.days(from: interval.start, to: interval.end, calendar: calendar))
    }

    /// «~3 h» para terminar el libro, con tu ritmo en él.
    func remaining(forBook id: UUID, progress: Double) -> TimeInterval? {
        guard progress < 0.99 else { return nil }
        return ReadingPeriod(sessions(forBook: id)).remainingSeconds(progress: progress)
    }

    func sessions(forBook id: UUID) -> [ReadingSession] {
        sessions.filter { $0.bookID == id }
    }

    var all: ReadingPeriod { ReadingPeriod(sessions) }

    /// El ritmo de una persona que lee con calma, mientras no hay sesiones tuyas.
    static let defaultWordsPerMinute: Double = 230

    /// Tu ritmo habitual (palabras por minuto), de tus últimas sesiones.
    var usualWordsPerMinute: Double? {
        let recent = sessions.suffix(20)
        let seconds = recent.reduce(0) { $0 + $1.readingSeconds }
        let words = recent.reduce(0) { $0 + $1.words }
        guard seconds >= 600, words > 0 else { return nil }
        return Double(words) / (seconds / 60)
    }
}

/// Mide la sesión mientras lees: cada página que ves, cuánto tiempo y cuántas
/// palabras, y las pausas al salir de la app. Al cerrar el libro, la sesión
/// pasa por `SessionClassifier` y se guarda.
@MainActor
final class SessionTracker: ObservableObject {
    /// Palabras de las páginas que terminaste en esta sesión.
    @Published private(set) var words = 0
    @Published private(set) var startedAt: Date?

    private let bookID: UUID?
    private var pages: [PageView] = []
    private var current: (start: Date, words: Int, fraction: Double)?
    private var paused = false
    private let sessionID = UUID()

    init(bookID: UUID?) {
        self.bookID = bookID
    }

    /// Nueva página en pantalla.
    func pageShown(words: Int, fraction: Double, jumped: Bool, at now: Date = Date()) {
        if let current {
            let forward = fraction > current.fraction && !jumped
            close(current, at: now, forward: forward, jumped: jumped)
        }
        if startedAt == nil { startedAt = now }
        current = paused ? nil : (now, words, fraction)
        pendingPage = (words, fraction)
    }

    /// La última página vista, para retomarla al volver a la app.
    private var pendingPage: (words: Int, fraction: Double)?

    /// Saliste de la app (o se bloqueó el teléfono).
    func pause(at now: Date = Date()) {
        guard !paused else { return }
        paused = true
        if let current { close(current, at: now, forward: false, jumped: false) }
        current = nil
    }

    /// Volviste a la app: la misma página sigue abierta.
    func resume(at now: Date = Date()) {
        guard paused else { return }
        paused = false
        if let page = pendingPage { current = (now, page.words, page.fraction) }
    }

    /// La sesión hasta ahora (para «Sesión actual»).
    func snapshot(at now: Date = Date()) -> ReadingSession? {
        guard let bookID else { return nil }
        var all = pages
        if let current { all.append(PageView(start: current.start, end: now, words: current.words, forward: false, fraction: current.fraction)) }
        return SessionClassifier(expectedWPM: SessionStore.shared.usualWordsPerMinute)
            .session(id: sessionID, bookID: bookID, device: AnnotationStore.deviceID, pages: all)
    }

    /// Cerraste el libro: guarda la sesión.
    func finish(at now: Date = Date()) {
        pause(at: now)
        guard let session = snapshot(at: now) else { return }
        pages = []
        SessionStore.shared.record(session)
    }

    private func close(_ page: (start: Date, words: Int, fraction: Double), at now: Date, forward: Bool, jumped: Bool) {
        let view = PageView(start: page.start, end: now, words: page.words, forward: forward, jumped: jumped, fraction: page.fraction)
        pages.append(view)
        if forward { words += page.words }
    }
}

extension SessionClassifier {
    /// Con tu ritmo habitual, si ya se conoce.
    init(expectedWPM: Double?) {
        self.init()
        if let expectedWPM { self.expectedWPM = min(max(expectedWPM, 120), 450) }
    }
}
