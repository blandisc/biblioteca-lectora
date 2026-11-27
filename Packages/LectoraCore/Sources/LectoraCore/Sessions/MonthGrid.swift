import Foundation

/// El mes como rejilla de lunes a domingo (Diario › Mes, UX-4b): los huecos antes del día 1,
/// los días y el renglón L M M J V S D de arriba.
///
/// Cada celda tiene su propia identidad. 26 nov 2026: el renglón de los días compartía la
/// rejilla y su identidad (la fecha) con los días del mes; cuando el mes empezaba en domingo,
/// el domingo del renglón y el día 1 eran «lo mismo» y el día 1 desaparecía.
public struct MonthGrid: Sendable {
    public enum Cell: Hashable, Identifiable, Sendable {
        /// Un hueco antes del día 1 (su lugar en la semana, desde 0).
        case blank(Int)
        /// Un día del mes (su lugar en `days`, desde 0).
        case day(Int)
        public var id: Self { self }
    }

    /// Lunes a domingo de la primera semana del mes, para el renglón de arriba.
    public let weekdays: [Date]
    /// Los huecos y después los días, en orden.
    public let cells: [Cell]

    /// `days`: los días del mes en orden (el primero es el día 1). La semana empieza en lunes
    /// aunque el calendario del dispositivo diga otra cosa.
    public init(days: [Date], calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        guard let first = days.first else {
            weekdays = []
            cells = []
            return
        }
        let weekday = calendar.component(.weekday, from: first)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        let monday = calendar.date(byAdding: .day, value: -blanks, to: first) ?? first
        weekdays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        cells = (0..<blanks).map(Cell.blank) + days.indices.map(Cell.day)
    }
}
