import Foundation

/// Las sesiones de lectura en la carpeta de la biblioteca
/// (`.lectora/sesiones/<dispositivo>.jsonl`): cada dispositivo agrega las suyas
/// y lee las de todos, como el registro de cambios. Una sesión no se edita.
public struct SessionLog: Sendable {
    public let directory: URL
    public let device: String

    public init(directory: URL, device: String) {
        self.directory = directory
        self.device = device
    }

    public var ownFile: URL { directory.appendingPathComponent("\(device).jsonl") }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    public func append(_ session: ReadingSession) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var data = try Self.encoder.encode(session)
        data.append(0x0A)
        if FileManager.default.fileExists(atPath: ownFile.path) {
            let handle = try FileHandle(forWritingTo: ownFile)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: ownFile, options: .atomic)
        }
    }

    /// Todas las sesiones de todos los dispositivos, de la más antigua a la más reciente.
    /// Las líneas a medio sincronizar se ignoran (llegan completas en la siguiente lectura).
    public func readAll() -> [ReadingSession] {
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "jsonl" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var seen = Set<UUID>()
        var sessions: [ReadingSession] = []
        for file in files {
            guard let data = try? Data(contentsOf: file) else { continue }
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                if let session = try? decoder.decode(ReadingSession.self, from: Data(line)), seen.insert(session.id).inserted {
                    sessions.append(session)
                }
            }
        }
        return sessions.sorted { $0.start < $1.start }
    }
}

/// Resúmenes del diario de lectura.
public struct ReadingPeriod: Sendable {
    public var sessions: [ReadingSession]

    public init(_ sessions: [ReadingSession]) { self.sessions = sessions }

    public var readingSeconds: TimeInterval { sessions.reduce(0) { $0 + $1.readingSeconds } }
    public var words: Int { sessions.reduce(0) { $0 + $1.words } }

    public func seconds(in stage: ReadingStage) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.seconds(in: stage) }
    }

    /// Días distintos con al menos una sesión.
    public func days(calendar: Calendar = .current) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.start) }).count
    }

    /// Libros de este periodo, con su tiempo, del que más al que menos.
    public func books() -> [(bookID: UUID, seconds: TimeInterval, sessions: Int, from: Double, to: Double)] {
        Dictionary(grouping: sessions, by: \.bookID)
            .map { id, items in
                let sorted = items.sorted { $0.start < $1.start }
                return (id, items.reduce(0) { $0 + $1.readingSeconds }, items.count,
                        sorted.first?.fromFraction ?? 0, sorted.last?.toFraction ?? 0)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// Las sesiones entre dos fechas (`start` incluida, `end` no).
    public func between(_ start: Date, _ end: Date) -> ReadingPeriod {
        ReadingPeriod(sessions.filter { $0.start >= start && $0.start < end })
    }

    /// La semana (lunes a domingo) que contiene `date`.
    public func week(of date: Date, calendar: Calendar = .current) -> ReadingPeriod {
        var calendar = calendar
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return self }
        return between(interval.start, interval.end)
    }
}
