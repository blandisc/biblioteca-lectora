import Foundation

/// Etapa de una sesión de lectura: cuánto sostienes la atención, no qué tan rápido lees.
public enum ReadingStage: String, Codable, CaseIterable, Sendable {
    /// Saliste de la app o te quedaste mucho rato sin avanzar.
    case interrupted
    /// Pasando páginas más rápido de lo que se lee.
    case skimming
    /// Leyendo, en un tramo seguido de menos de `lightLimit`.
    case light
    /// Tramo seguido entre `lightLimit` y `activeLimit`.
    case active
    /// Tramo seguido de `activeLimit` o más.
    case immersed

    public var title: String {
        switch self {
        case .interrupted: "Interrumpida"
        case .skimming: "Hojeo"
        case .light: "Ligera"
        case .active: "Activa"
        case .immersed: "Inmersa"
        }
    }

    /// Las que cuentan como lectura.
    public var isReading: Bool { self == .light || self == .active || self == .immersed }
}

/// Una página vista en el lector.
public struct PageView: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    /// Palabras de la página.
    public var words: Int
    /// Llegaste pasando a la siguiente página (no hacia atrás ni saltando).
    public var forward: Bool
    /// Llegaste por el índice, la barra o un enlace.
    public var jumped: Bool
    /// Avance en el libro al ver la página (0 a 1).
    public var fraction: Double

    public init(start: Date, end: Date, words: Int, forward: Bool = true, jumped: Bool = false, fraction: Double = 0) {
        self.start = start
        self.end = end
        self.words = words
        self.forward = forward
        self.jumped = jumped
        self.fraction = fraction
    }

    public var dwell: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// Un tramo de la sesión en una etapa.
public struct StageSegment: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var stage: ReadingStage

    public init(start: Date, end: Date, stage: ReadingStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// Una sesión terminada: lo que se guarda en `.lectora/sesiones/<dispositivo>.jsonl`.
public struct ReadingSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var bookID: UUID
    public var device: String
    public var start: Date
    public var end: Date
    /// Palabras de páginas nuevas, avanzando (releer no suma).
    public var words: Int
    /// Tiempo leyendo de verdad (sin interrupciones ni hojeo).
    public var readingSeconds: TimeInterval
    public var fromFraction: Double
    public var toFraction: Double
    public var segments: [StageSegment]
    /// El tramo más largo sin interrupciones, en segundos.
    public var longestStreak: TimeInterval

    public var elapsed: TimeInterval { max(0, end.timeIntervalSince(start)) }

    /// Palabras por minuto mientras leías (no cuenta pausas ni hojeo).
    public var wordsPerMinute: Int? {
        guard readingSeconds >= 30, words > 0 else { return nil }
        return Int((Double(words) / (readingSeconds / 60)).rounded())
    }

    public func seconds(in stage: ReadingStage) -> TimeInterval {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    public func times(in stage: ReadingStage) -> Int {
        segments.filter { $0.stage == stage }.count
    }
}
