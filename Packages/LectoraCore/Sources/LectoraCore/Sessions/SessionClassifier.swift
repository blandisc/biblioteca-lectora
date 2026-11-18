import Foundation

/// Convierte las páginas vistas en una sesión con etapas.
///
/// Por cada página se calcula cuánto tardaste y a qué ritmo:
/// - **Pausa:** si entre una página y la siguiente pasó tiempo sin ninguna
///   abierta (saliste de la app), o si te quedaste en una página más de lo
///   razonable, lo que sobra es **Interrumpida** y corta el tramo.
/// - **Hojeo:** páginas de menos de `minDwell` o a más de `skimWPM`. También corta el tramo.
/// - **Lectura:** lo demás. Su etapa depende de cuánto lleva el tramo seguido:
///   **Ligera** al principio, **Activa** desde `lightLimit`, **Inmersa** desde `activeLimit`.
public struct SessionClassifier: Sendable {
    /// Ritmo de lectura esperado (palabras por minuto) para saber qué es «mucho rato».
    public var expectedWPM: Double = 230
    /// Más rápido que esto es pasar páginas, no leer.
    public var skimWPM: Double = 600
    /// Una página de menos de esto, con texto, es hojeo.
    public var minDwell: TimeInterval = 3
    /// Una página cuenta como lectura hasta `stallFactor` veces lo esperado (y al menos `minStall`).
    public var stallFactor: Double = 2.5
    public var minStall: TimeInterval = 120
    /// Un hueco entre páginas mayor a esto es una interrupción.
    public var gapTolerance: TimeInterval = 5
    public var lightLimit: TimeInterval = 5 * 60
    public var activeLimit: TimeInterval = 15 * 60

    public init() {}

    public func session(id: UUID = UUID(), bookID: UUID, device: String, pages: [PageView]) -> ReadingSession? {
        let pages = pages.sorted { $0.start < $1.start }
        guard let first = pages.first, let last = pages.last else { return nil }

        var segments: [StageSegment] = []
        var streak: TimeInterval = 0
        var longest: TimeInterval = 0
        var reading: TimeInterval = 0
        var words = 0
        var previousEnd: Date?

        func add(_ start: Date, _ end: Date, _ stage: ReadingStage) {
            guard end > start else { return }
            if let lastSegment = segments.last, lastSegment.stage == stage,
               abs(lastSegment.end.timeIntervalSince(start)) < 1 {
                segments[segments.count - 1].end = end
            } else {
                segments.append(StageSegment(start: start, end: end, stage: stage))
            }
        }

        func breakStreak() {
            longest = max(longest, streak)
            streak = 0
        }

        for page in pages {
            if let previousEnd, page.start.timeIntervalSince(previousEnd) > gapTolerance {
                add(previousEnd, page.start, .interrupted)
                breakStreak()
            }
            previousEnd = page.end

            let dwell = page.dwell
            guard dwell > 0 else { continue }
            let expected = Double(max(page.words, 1)) / expectedWPM * 60
            let limit = max(expected * stallFactor, minStall)
            let readTime = min(dwell, limit)
            let wpm = Double(page.words) / (readTime / 60)

            if page.words > 0, dwell < minDwell || wpm > skimWPM {
                add(page.start, page.end, .skimming)
                breakStreak()
                continue
            }

            // Lectura: la etapa de cada parte depende de lo que lleva el tramo.
            var cursor = page.start
            let readEnd = page.start.addingTimeInterval(readTime)
            for (limit, stage) in [(lightLimit, ReadingStage.light), (activeLimit, .active), (.infinity, .immersed)] {
                guard cursor < readEnd else { break }
                let untilStageEnds = limit - streak
                guard untilStageEnds > 0 else { continue }
                let end = min(readEnd, cursor.addingTimeInterval(untilStageEnds))
                add(cursor, end, stage)
                streak += end.timeIntervalSince(cursor)
                cursor = end
            }
            reading += readTime
            if page.forward && !page.jumped { words += page.words }

            if dwell > readTime {
                add(readEnd, page.end, .interrupted)
                breakStreak()
            }
        }
        breakStreak()

        return ReadingSession(
            id: id, bookID: bookID, device: device,
            start: first.start, end: max(last.end, first.start),
            words: words, readingSeconds: reading,
            fromFraction: first.fraction, toFraction: last.fraction,
            segments: segments, longestStreak: longest
        )
    }
}
