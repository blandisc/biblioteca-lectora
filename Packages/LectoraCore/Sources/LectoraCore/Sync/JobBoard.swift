import Foundation

/// Trabajo pendiente para un servicio externo: mandar un subrayado a Readwise,
/// el avance a Hardcover… Vive en el registro compartido de la biblioteca.
public struct Job: Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Qué hay que hacer («readwise.subrayado», «hardcover.avance»…).
    public var kind: String
    /// Sobre qué (el id del subrayado, del libro…).
    public var target: String
    /// Datos del trabajo, si hacen falta.
    public var payload: JSONValue
    public var createdAt: Date
    /// Toma de cada dispositivo: cuándo dijo «lo hago yo».
    public var claims: [String: Date]
    public var done: Bool
    public var attempts: Int
    public var lastError: String?
    /// Antes de esta hora no se reintenta (tras un error).
    public var notBefore: Date?
}

/// Un trabajo, un dispositivo (arquitectura D7): sin servidor, el iPhone y el
/// Mac comparten la lista de trabajos en sus registros y cada trabajo lo hace
/// uno solo.
///
/// - **Mismo trabajo, mismo id:** el id sale de `kind` + `target`, así que si
///   los dos dispositivos lo anotan es el mismo trabajo.
/// - **Tomar:** cada dispositivo escribe su propia toma (`claim.<dispositivo>`,
///   con la hora). Como cada uno escribe un campo distinto, ninguna toma borra
///   a otra al sincronizar.
/// - **Quién lo hace:** la toma vigente más antigua (desempata el nombre). Una
///   toma vence después de `lease` sin terminar, y entonces otro la retoma.
/// - **Esperar a que llegue la sincronización:** un dispositivo solo empieza
///   cuando su toma lleva `settle` segundos, para que iCloud alcance a traer la
///   toma del otro si fue anterior.
///
/// Esto evita casi todo el trabajo repetido; lo que quede (dos tomas que no se
/// vieron a tiempo) lo absorbe el conector, que debe ser idempotente.
public struct JobBoard: Sendable {
    public var lease: TimeInterval
    public var settle: TimeInterval

    public init(lease: TimeInterval = 10 * 60, settle: TimeInterval = 45) {
        self.lease = lease
        self.settle = settle
    }

    enum Field {
        static let kind = "kind"
        static let target = "target"
        static let payload = "payload"
        static let createdAt = "created_at"
        static let claimPrefix = "claim."
        static let done = "done"
        static let attempts = "attempts"
        static let lastError = "last_error"
        static let notBefore = "not_before"
    }

    /// Id estable de un trabajo: el mismo en todos los dispositivos.
    public static func jobID(kind: String, target: String) -> UUID {
        StableID.uuid(for: "job|\(kind)|\(target)")
    }

    /// Anota un trabajo. Si ya existía (aunque esté hecho), no cambia nada.
    public func enqueue(kind: String, target: String, payload: JSONValue = .null,
                        in state: LibraryState, clock: HybridLogicalClock, now: Date = Date()) -> [Change] {
        let id = Self.jobID(kind: kind, target: target)
        guard state.fields(of: .job, id: id)?[Field.kind] == nil else { return [] }
        return [
            (Field.kind, JSONValue.string(kind)),
            (Field.target, .string(target)),
            (Field.payload, payload),
            (Field.createdAt, .number(now.timeIntervalSince1970)),
        ].map { Change(hlc: clock.tick(), entity: .job, entityID: id, field: $0.0, value: $0.1) }
    }

    /// Vuelve a abrir un trabajo hecho (p. ej. el subrayado cambió y hay que mandarlo otra vez).
    public func reopen(_ id: UUID, payload: JSONValue? = nil, clock: HybridLogicalClock) -> [Change] {
        var changes = [Change(hlc: clock.tick(), entity: .job, entityID: id, field: Field.done, value: .bool(false))]
        if let payload {
            changes.append(Change(hlc: clock.tick(), entity: .job, entityID: id, field: Field.payload, value: payload))
        }
        return changes
    }

    public func claim(_ id: UUID, device: String, clock: HybridLogicalClock, now: Date = Date()) -> [Change] {
        [Change(hlc: clock.tick(), entity: .job, entityID: id, field: Field.claimPrefix + device,
                value: .number(now.timeIntervalSince1970))]
    }

    public func complete(_ id: UUID, device: String, clock: HybridLogicalClock) -> [Change] {
        [
            Change(hlc: clock.tick(), entity: .job, entityID: id, field: Field.done, value: .bool(true)),
            Change(hlc: clock.tick(), entity: .job, entityID: id, field: Field.claimPrefix + device, value: .null),
        ]
    }

    /// Falló: suelta la toma y espera antes de reintentar (1, 2, 4… minutos, hasta una hora).
    public func fail(_ job: Job, device: String, error: String, clock: HybridLogicalClock, now: Date = Date()) -> [Change] {
        let attempts = job.attempts + 1
        let wait = min(60 * pow(2, Double(attempts - 1)), 3600)
        return [
            (Field.claimPrefix + device, JSONValue.null),
            (Field.attempts, .number(Double(attempts))),
            (Field.lastError, .string(error)),
            (Field.notBefore, .number(now.addingTimeInterval(wait).timeIntervalSince1970)),
        ].map { Change(hlc: clock.tick(), entity: .job, entityID: job.id, field: $0.0, value: $0.1) }
    }

    /// El dispositivo que tiene el trabajo ahora, si alguno.
    public func owner(of job: Job, now: Date = Date()) -> String? {
        job.claims
            .filter { now.timeIntervalSince($0.value) < lease }
            .min { ($0.value, $0.key) < ($1.value, $1.key) }?
            .key
    }

    /// Trabajos sin hacer que este dispositivo puede tomar ahora (nadie los tiene).
    public func claimable(in state: LibraryState, device: String, now: Date = Date()) -> [Job] {
        Self.jobs(in: state).filter { job in
            !job.done && (job.notBefore.map { $0 <= now } ?? true) && owner(of: job, now: now) == nil
        }
    }

    /// Trabajos que este dispositivo debe hacer ya: la toma es suya y ya esperó `settle`.
    public func runnable(in state: LibraryState, device: String, now: Date = Date()) -> [Job] {
        Self.jobs(in: state).filter { job in
            guard !job.done, owner(of: job, now: now) == device, let mine = job.claims[device] else { return false }
            return now.timeIntervalSince(mine) >= settle
        }
    }

    public static func jobs(in state: LibraryState) -> [Job] {
        state.ids(of: .job).compactMap { job(id: $0, in: state) }.sorted { $0.createdAt < $1.createdAt }
    }

    public static func job(id: UUID, in state: LibraryState) -> Job? {
        guard let fields = state.fields(of: .job, id: id),
              let kind = fields[Field.kind]?.stringValue,
              let target = fields[Field.target]?.stringValue
        else { return nil }
        var claims: [String: Date] = [:]
        for (field, value) in fields where field.hasPrefix(Field.claimPrefix) {
            if let seconds = value.doubleValue {
                claims[String(field.dropFirst(Field.claimPrefix.count))] = Date(timeIntervalSince1970: seconds)
            }
        }
        return Job(
            id: id, kind: kind, target: target,
            payload: fields[Field.payload] ?? .null,
            createdAt: Date(timeIntervalSince1970: fields[Field.createdAt]?.doubleValue ?? 0),
            claims: claims,
            done: fields[Field.done]?.boolValue ?? false,
            attempts: Int(fields[Field.attempts]?.doubleValue ?? 0),
            lastError: fields[Field.lastError]?.stringValue,
            notBefore: fields[Field.notBefore]?.doubleValue.map(Date.init(timeIntervalSince1970:))
        )
    }
}

/// Ids estables a partir de un texto (FNV-1a de 128 bits), iguales en todos los dispositivos.
public enum StableID {
    public static func uuid(for text: String) -> UUID {
        var a: UInt64 = 0xcbf2_9ce4_8422_2325
        var b: UInt64 = 0x8422_2325_cbf2_9ce4
        for byte in text.utf8 {
            a = (a ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            b = (b ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            b = b &+ (a >> 29)
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: a >> (8 * i))
            bytes[8 + i] = UInt8(truncatingIfNeeded: b >> (8 * i))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // versión 5 (por nombre)
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
