import Foundation
import LectoraCore
import Security

/// Llaves de los servicios en el Llavero, sincronizado por iCloud: se ponen una
/// vez y sirven en el iPhone y en el Mac (arquitectura D6).
enum ConnectorKeychain {
    private static let service = "Gabinete.conectores"

    static func key(for connector: Connector) -> String? {
        var query = baseQuery(connector)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String, for connector: Connector) {
        delete(connector)
        var item = baseQuery(connector)
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ connector: Connector) {
        SecItemDelete(baseQuery(connector) as CFDictionary)
    }

    private static func baseQuery(_ connector: Connector) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connector.rawValue,
            kSecAttrSynchronizable as String: true,
        ]
    }
}

/// Los servicios a los que se conecta Gabinete.
enum Connector: String, CaseIterable, Identifiable {
    case readwise
    case hardcover

    var id: Self { self }

    var title: String {
        switch self {
        case .readwise: "Readwise"
        case .hardcover: "Hardcover"
        }
    }

    /// Qué hace, en una línea.
    var summary: String {
        switch self {
        case .readwise: "Tus subrayados, en las dos direcciones"
        case .hardcover: "Qué lees y tu avance"
        }
    }

    /// Dónde está la llave.
    var keyHelp: String {
        switch self {
        case .readwise: "La encuentras en readwise.io/access_token."
        case .hardcover: "La encuentras en hardcover.app › Ajustes › Hardcover API. Puedes pegarla con o sin «Bearer»."
        }
    }

    var explanation: String {
        switch self {
        case .readwise:
            "Tus subrayados de Gabinete van a Readwise con su libro, su nota y un enlace que vuelve al pasaje. De Readwise llegan los de Kindle, Apple Books y tus otras fuentes. Si borras o editas uno aquí, también allá. Nada se duplica."
        case .hardcover:
            "Al leer, el libro queda como «Leyendo» en tu Hardcover con tu avance, y como «Leído» con su fecha al terminar. Gabinete manda; de Hardcover no traigo nada."
        }
    }
}

/// Ajustes de los conectores (en este dispositivo).
enum ConnectorKeys {
    static let readwiseSend = "readwise.mandar"
    static let readwiseReceive = "readwise.traer"
    static let readwiseLastImport = "readwise.ultimaImportacion"
    static let hardcoverFinish = "hardcover.marcarLeido"
    static let hardcoverSent = "hardcover.enviado"
    /// Calificación mandada por libro (para mandarla otra vez si cambia).
    static let hardcoverRated = "hardcover.calificado"
    /// Páginas de cada libro en Hardcover (para mandar el avance en páginas).
    static let hardcoverPages = "hardcover.paginas"
    static func lastSync(_ connector: Connector) -> String { "\(connector.rawValue).ultimaSincronizacion" }
    static func username(_ connector: Connector) -> String { "\(connector.rawValue).usuario" }
}

/// Readwise ⇄ y Hardcover →, sin servidor: cada dispositivo habla directo con
/// el servicio con tu llave, y los envíos pasan por la lista de trabajos
/// compartida para que solo un dispositivo haga cada uno (D7).
@MainActor
final class ConnectorsStore: ObservableObject {
    /// Cada cuánto se sincronizan los servicios conectados mientras la app está abierta.
    static let syncEvery: Duration = .seconds(60)
    static let shared = ConnectorsStore()

    enum Status: Equatable {
        case off
        case idle
        case syncing
        case failed(String)
    }

    @Published private(set) var status: [Connector: Status] = [:]

    private let library: LibraryStore
    private let annotations: AnnotationStore
    private let sessions: SessionStore
    private let defaults = UserDefaults.standard
    private var syncing = false
    private var loop: Task<Void, Never>?

    enum Kind {
        static let readwiseSend = "readwise.subrayado"
        static let readwiseNote = "readwise.nota"
        static let readwiseDelete = "readwise.borrar"
        static let hardcoverProgress = "hardcover.avance"
        static let readwise: Set<String> = [readwiseSend, readwiseNote, readwiseDelete]
        static let hardcover: Set<String> = [hardcoverProgress]
    }

    // Los valores por defecto se calculan fuera del hilo principal; las tiendas viven en él,
    // así que se resuelven aquí adentro (si no, Swift 6 lo marca como error).
    init(library: LibraryStore? = nil, annotations: AnnotationStore? = nil, sessions: SessionStore? = nil) {
        self.library = library ?? .shared
        self.annotations = annotations ?? .shared
        self.sessions = sessions ?? .shared
        for connector in Connector.allCases {
            status[connector] = isConnected(connector) ? .idle : .off
        }
        self.annotations.onChange = { [weak self] before, after in self?.annotationChanged(before: before, after: after) }
    }

    func isConnected(_ connector: Connector) -> Bool { ConnectorKeychain.key(for: connector) != nil }

    func lastSync(_ connector: Connector) -> Date? { defaults.object(forKey: ConnectorKeys.lastSync(connector)) as? Date }

    func username(_ connector: Connector) -> String? { defaults.string(forKey: ConnectorKeys.username(connector)) }

    func pending(_ connector: Connector) -> Int {
        library.pendingJobs(kinds: connector == .readwise ? Kind.readwise : Kind.hardcover).count
    }

    // MARK: Conectar

    /// Prueba la llave y, si sirve, la guarda y sincroniza.
    func connect(_ connector: Connector, key: String) async throws {
        switch connector {
        case .readwise:
            try await ReadwiseClient(token: key).verify()
        case .hardcover:
            let name = try await HardcoverClient(token: key).verify()
            defaults.set(name, forKey: ConnectorKeys.username(connector))
        }
        ConnectorKeychain.save(key, for: connector)
        status[connector] = .idle
        await sync()
    }

    func disconnect(_ connector: Connector) {
        ConnectorKeychain.delete(connector)
        defaults.removeObject(forKey: ConnectorKeys.lastSync(connector))
        defaults.removeObject(forKey: ConnectorKeys.username(connector))
        status[connector] = .off
    }

    // MARK: Sincronizar

    /// Mientras la app está abierta, cada minuto (los trabajos esperan a que
    /// la toma de este dispositivo se asiente antes de correr).
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(for: Self.syncEvery)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func sync() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        if let key = ConnectorKeychain.key(for: .readwise) { await syncReadwise(ReadwiseClient(token: key)) }
        if let key = ConnectorKeychain.key(for: .hardcover) { await syncHardcover(HardcoverClient(token: key)) }
    }

    private func finish(_ connector: Connector, error: Error?) {
        if let error {
            status[connector] = .failed(error.localizedDescription)
        } else {
            status[connector] = .idle
            defaults.set(Date(), forKey: ConnectorKeys.lastSync(connector))
        }
    }

    // MARK: Readwise

    private var sendsToReadwise: Bool { defaults.object(forKey: ConnectorKeys.readwiseSend) as? Bool ?? true }
    private var receivesFromReadwise: Bool { defaults.object(forKey: ConnectorKeys.readwiseReceive) as? Bool ?? true }

    private func syncReadwise(_ client: ReadwiseClient) async {
        status[.readwise] = .syncing
        do {
            if sendsToReadwise {
                for annotation in annotations.allAnnotations() where annotation.isOwn && annotation.readwiseID == nil {
                    library.enqueueJob(kind: Kind.readwiseSend, target: annotation.id.uuidString)
                }
                try await runReadwiseJobs(client)
            }
            if receivesFromReadwise { try await importFromReadwise(client) }
            finish(.readwise, error: nil)
        } catch {
            finish(.readwise, error: error)
        }
    }

    private func runReadwiseJobs(_ client: ReadwiseClient) async throws {
        let jobs = library.takeJobs(kinds: Kind.readwise)
        // Nuevos, en un solo envío.
        let sends = jobs.filter { $0.kind == Kind.readwiseSend }
        var outgoing: [(Job, ReadwiseClient.Outgoing)] = []
        for job in sends {
            guard let id = UUID(uuidString: job.target), let annotation = annotations.annotation(id: id),
                  annotation.readwiseID == nil, annotations.allAnnotations().contains(where: { $0.id == id })
            else { library.completeJob(job); continue }
            let book = library.book(id: annotation.bookID)
            outgoing.append((job, .init(annotationID: id, text: annotation.quote,
                                        title: book?.title ?? annotation.bookTitle ?? MetadataCleaner.untitled,
                                        author: book?.authors.joined(separator: ", ") ?? annotation.bookAuthor,
                                        note: annotation.note, location: nil, highlightedAt: annotation.createdAt)))
        }
        if !outgoing.isEmpty {
            do {
                let ids = try await client.send(outgoing.map(\.1))
                for (job, highlight) in outgoing {
                    if let readwiseID = ids[highlight.annotationID], var annotation = annotations.annotation(id: highlight.annotationID) {
                        annotation.readwiseID = readwiseID
                        try? annotations.save(annotation)
                    }
                    library.completeJob(job)
                }
            } catch {
                outgoing.forEach { library.failJob($0.0, error: error) }
                throw error
            }
        }
        // Notas editadas y borrados, uno por uno.
        for job in jobs where job.kind != Kind.readwiseSend {
            do {
                if job.kind == Kind.readwiseDelete {
                    try await client.delete(id: job.target)
                } else if let annotation = annotations.allAnnotations().first(where: { $0.readwiseID == job.target }) {
                    try await client.update(id: job.target, text: nil, note: annotation.note ?? "")
                }
                library.completeJob(job)
            } catch {
                library.failJob(job, error: error)
                throw error
            }
        }
    }

    private func importFromReadwise(_ client: ReadwiseClient) async throws {
        let since = defaults.object(forKey: ConnectorKeys.readwiseLastImport) as? Date
        let started = Date()
        let incoming = try await client.export(updatedAfter: since)
        let existing = annotations.allAnnotations()
        for action in ReadwiseMerge.actions(incoming: incoming, existing: existing) {
            switch action {
            case .create(let highlight):
                let book = ReadwiseMerge.book(for: highlight, in: library.books)
                let annotation = Annotation(
                    bookID: book?.id ?? ReadwiseMerge.outsideBookID(title: highlight.bookTitle, author: highlight.bookAuthor),
                    cfi: nil, quote: highlight.text, color: "pencil", note: highlight.note,
                    createdAt: highlight.highlightedAt ?? highlight.updatedAt ?? Date(),
                    readwiseID: highlight.id, source: ReadwiseClient.source,
                    bookTitle: highlight.bookTitle, bookAuthor: highlight.bookAuthor)
                try? saveQuietly(annotation)
            case .update(let id, let text, let note):
                if var annotation = annotations.annotation(id: id) {
                    annotation.quote = text
                    annotation.note = note
                    try? saveQuietly(annotation)
                }
            case .delete(let id):
                try? deleteQuietly(id)
            }
        }
        defaults.set(started, forKey: ConnectorKeys.readwiseLastImport)
    }

    /// Lo que llega de Readwise no se vuelve a mandar allá.
    private func saveQuietly(_ annotation: Annotation) throws {
        let hook = annotations.onChange
        annotations.onChange = nil
        defer { annotations.onChange = hook }
        try annotations.save(annotation)
    }

    private func deleteQuietly(_ id: UUID) throws {
        let hook = annotations.onChange
        annotations.onChange = nil
        defer { annotations.onChange = hook }
        try annotations.delete(id: id)
    }

    /// Editaste la nota o borraste un subrayado que ya está en Readwise: allá también.
    private func annotationChanged(before: Annotation?, after: Annotation?) {
        guard isConnected(.readwise), sendsToReadwise, let readwiseID = before?.readwiseID ?? after?.readwiseID else { return }
        if after == nil {
            library.enqueueJob(kind: Kind.readwiseDelete, target: readwiseID)
        } else if before?.note != after?.note {
            library.enqueueJob(kind: Kind.readwiseNote, target: readwiseID, payload: .string(after?.note ?? ""), reopen: true)
        }
    }

    // MARK: Hardcover

    private var marksFinished: Bool { defaults.object(forKey: ConnectorKeys.hardcoverFinish) as? Bool ?? true }

    private func syncHardcover(_ client: HardcoverClient) async {
        status[.hardcover] = .syncing
        // Lo que se mandó por libro (porcentaje), para no repetir.
        var sent = defaults.dictionary(forKey: ConnectorKeys.hardcoverSent) as? [String: Double] ?? [:]
        var rated = defaults.dictionary(forKey: ConnectorKeys.hardcoverRated) as? [String: Double] ?? [:]
        for book in library.books {
            guard let position = library.position(for: book.id), position.fraction > 0 else { continue }
            let key = book.id.uuidString
            let percent = (position.fraction * 100).rounded()
            let rating = book.rating ?? 0
            let moved = sent[key].map { abs($0 - percent) >= 1 } ?? true
            let rerated = (rated[key] ?? 0) != rating
            guard moved || rerated else { continue }
            library.enqueueJob(kind: Kind.hardcoverProgress, target: key, payload: .number(position.fraction), reopen: true)
            sent[key] = percent
            rated[key] = rating
        }
        defaults.set(sent, forKey: ConnectorKeys.hardcoverSent)
        defaults.set(rated, forKey: ConnectorKeys.hardcoverRated)
        do {
            for job in library.takeJobs(kinds: Kind.hardcover) {
                do {
                    try await sendProgress(job, client: client)
                    library.completeJob(job)
                } catch {
                    library.failJob(job, error: error)
                    throw error
                }
            }
            finish(.hardcover, error: nil)
        } catch {
            finish(.hardcover, error: error)
        }
    }

    private func sendProgress(_ job: Job, client: HardcoverClient) async throws {
        guard let id = UUID(uuidString: job.target), let book = library.book(id: id) else { return }
        let progress = job.payload.doubleValue ?? library.position(for: id)?.fraction ?? 0
        // El libro en Hardcover: el que ya se encontró antes, o se busca una vez.
        var hardcoverID = book.identifiers[HardcoverClient.identifierKey].flatMap(Int.init)
        var pages: Int?
        if hardcoverID == nil {
            let isbn = book.identifiers["isbn"]
            guard let match = try await client.find(title: book.title, authors: book.authors, isbn: isbn) else {
                throw ConnectorError.unexpected("No encontré «\(book.title)» en Hardcover.")
            }
            hardcoverID = match.id
            pages = match.pages
            // Como openlibrary: o google:, queda en el catálogo y en el OPF (Calibre lo respeta).
            // Solo ese dato, sobre el libro de ahora (auditoría 5): mientras preguntaba a Hardcover
            // pudiste editarlo, y guardar la copia de antes revertía tu cambio.
            if var current = library.book(id: id) {
                current.identifiers[HardcoverClient.identifierKey] = String(match.id)
                _ = try? library.update(current)
            }
            var known = defaults.dictionary(forKey: ConnectorKeys.hardcoverPages) as? [String: Int] ?? [:]
            known[String(match.id)] = match.pages
            defaults.set(known, forKey: ConnectorKeys.hardcoverPages)
        } else {
            pages = (defaults.dictionary(forKey: ConnectorKeys.hardcoverPages) as? [String: Int])?[String(hardcoverID ?? 0)]
        }
        guard let hardcoverID else { return }
        let finished = progress >= 0.99 && marksFinished
        // La valoración de ahora, no la de antes de preguntar.
        let latest = library.book(id: id) ?? book
        let started = sessions.sessions(forBook: id).first?.start ?? latest.addedAt
        try await client.apply(.init(
            bookID: hardcoverID,
            status: finished ? .read : HardcoverClient.status(for: min(progress, 0.98)),
            progress: progress, pages: pages,
            startedAt: started, finishedAt: finished ? Date() : nil,
            rating: latest.rating.flatMap { $0 > 0 ? $0 : nil }))
    }

    // MARK: Salida libre

    /// Todos tus subrayados en el CSV que Readwise importa (y cualquier hoja de cálculo).
    func exportCSV() throws -> URL {
        let rows = annotations.allAnnotations().map { annotation in
            let book = library.book(id: annotation.bookID)
            return (annotation, book?.title ?? annotation.bookTitle ?? MetadataCleaner.untitled,
                    book?.authors.joined(separator: ", ") ?? annotation.bookAuthor)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Gabinete-subrayados.csv")
        try Data(ReadwiseCSV.export(rows).utf8).write(to: url, options: .atomic)
        return url
    }
}
