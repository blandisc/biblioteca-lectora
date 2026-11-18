import LectoraCore
import SwiftUI

/// Ir al diario (desde «Esta semana» en la Mesa).
struct DiaryRef: Hashable {}

/// Ir a una sesión pasada.
struct SessionRef: Hashable {
    let id: UUID
}

/// Diario de lectura: tu semana, tu mes y tu año. Sin metas ni rachas: lo que
/// leíste y cuánto sostuviste la atención, contado en palabras.
struct DiaryScreen: View {
    enum Part: String, CaseIterable, Identifiable {
        case week = "Semana"
        case month = "Mes"
        case year = "Año"
        var id: Self { self }
    }

    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = SessionStore.shared
    @State private var part: Part = .week
    /// Cuántas semanas, meses o años hacia atrás.
    @State private var offset = 0

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private var all: ReadingPeriod { store.all }

    private var continueAction: (() -> Void)? {
        model.currentBook == nil ? nil : { model.continueReading() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Diario")
                FilterBar(items: Part.allCases, selection: $part) { $0.rawValue }
                    .padding(.top, Theme.Space.m)
                if store.sessions.isEmpty {
                    EmptyState(title: "Tu diario empieza al leer",
                               message: "Cada vez que abres un libro, Gabinete anota la sesión: cuánto leíste, a qué ritmo y cuánto tiempo sostuviste la atención. No hay metas que cumplir ni rachas que perder. Todo se queda en tu Gabinete.",
                               actionTitle: model.currentBook.map { "Seguir leyendo \($0.title)" },
                               action: continueAction)
                } else {
                    switch part {
                    case .week: week.padding(.top, Theme.Space.l)
                    case .month: month.padding(.top, Theme.Space.l)
                    case .year: year.padding(.top, Theme.Space.l)
                    }
                }
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: part) { _, _ in offset = 0 }
    }

    // MARK: Semana

    private var weekInterval: DateInterval {
        let base = calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()) ?? Date()
        return calendar.dateInterval(of: .weekOfYear, for: base) ?? DateInterval(start: base, duration: 0)
    }

    @ViewBuilder
    private var week: some View {
        let interval = weekInterval
        let period = all.between(interval.start, interval.end)
        let previous = all.between(interval.start.addingTimeInterval(-7 * 86_400), interval.start)
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            PeriodStepper(title: weekTitle(interval), canGoForward: offset > 0,
                          back: { offset += 1 }, forward: { offset -= 1 })
            PeriodTotal(period: period, days: calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 7, calendar: calendar)
            WeekBars(days: period.days(from: interval.start, to: interval.end, calendar: calendar))
            StageLegend { period.seconds(in: $0) }
            if let line = comparison(period, previous) {
                Text(line).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }
            booksSection(period)
            sessionsSection(period)
        }
    }

    private func weekTitle(_ interval: DateInterval) -> String {
        let end = interval.end.addingTimeInterval(-1)
        return "\(interval.start.formatted(.dateTime.day())) – \(end.formatted(.dateTime.day().month(.wide)))"
    }

    /// «Leíste 23 min más que la semana pasada, y casi la mitad del tiempo fue inmersa».
    private func comparison(_ period: ReadingPeriod, _ previous: ReadingPeriod) -> String? {
        let difference = period.readingSeconds - previous.readingSeconds
        guard period.readingSeconds > 0, previous.readingSeconds > 0, abs(difference) >= 60 else { return nil }
        let direction = difference > 0 ? "más" : "menos"
        let share = Int((period.immersedShare * 100).rounded())
        return "Leíste \(ReadingFormat.duration(abs(difference))) \(direction) que la semana pasada; el \(share) % del tiempo fue inmersa."
    }

    // MARK: Mes

    private var monthInterval: DateInterval {
        let base = calendar.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
        return calendar.dateInterval(of: .month, for: base) ?? DateInterval(start: base, duration: 0)
    }

    @ViewBuilder
    private var month: some View {
        let interval = monthInterval
        let period = all.between(interval.start, interval.end)
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            PeriodStepper(title: interval.start.formatted(.dateTime.month(.wide).year()).capitalized,
                          canGoForward: offset > 0, back: { offset += 1 }, forward: { offset -= 1 })
            PeriodTotal(period: period, days: calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30, calendar: calendar)
            MonthCalendar(days: period.days(from: interval.start, to: interval.end, calendar: calendar))
            let longest = period.sessions.sorted { $0.readingSeconds > $1.readingSeconds }.prefix(2)
            if !longest.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Lo más largo")
                    ForEach(Array(longest)) { session in
                        NavigationLink(value: SessionRef(id: session.id)) {
                            SessionRow(session: session, bookTitle: title(of: session.bookID))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            finishedSection(period)
        }
    }

    // MARK: Año

    @ViewBuilder
    private var year: some View {
        let base = calendar.date(byAdding: .year, value: -offset, to: Date()) ?? Date()
        let interval = calendar.dateInterval(of: .year, for: base) ?? DateInterval(start: base, duration: 0)
        let period = all.between(interval.start, interval.end)
        let months = all.months(ofYearContaining: base, calendar: calendar)
        let current = offset == 0 ? calendar.component(.month, from: Date()) - 1 : -1
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            PeriodStepper(title: ReadingFormat.roman(calendar.component(.year, from: base)), roman: true,
                          canGoForward: offset > 0, back: { offset += 1 }, forward: { offset -= 1 })
            StatTrio(items: [
                .init(value: ReadingFormat.duration(period.readingSeconds), label: "leyendo"),
                .init(value: "\(finished(period).count)", label: "libros terminados"),
                .init(value: ReadingFormat.words(period.words), label: "palabras"),
            ])
            YearBars(months: months, current: current)
            attention(period, interval: interval)
            finishedSection(period)
        }
    }

    /// «Tu atención»: tiempo inmersa este año frente al primer mes con lecturas.
    private func attention(_ period: ReadingPeriod, interval: DateInterval) -> some View {
        let first = period.sessions.first.map { calendar.dateInterval(of: .month, for: $0.start) } ?? nil
        let firstShare = first.map { all.between($0.start, $0.end).immersedShare }
        let typical = period.sessions.map(\.readingSeconds).sorted()
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionLabel(text: "Tu atención")
            FactRow(label: "Tiempo inmersa", value: shareLine(period.immersedShare, since: firstShare, month: first?.start))
            if !typical.isEmpty {
                FactRow(label: "Sesión típica", value: ReadingFormat.duration(typical[typical.count / 2]))
            }
            if let wpm = period.wordsPerMinute {
                FactRow(label: "Ritmo", value: "\(wpm) palabras/min")
            }
        }
    }

    private func shareLine(_ share: Double, since first: Double?, month: Date?) -> String {
        let now = "\(Int((share * 100).rounded())) %"
        guard let first, let month, abs(first - share) >= 0.02 else { return now }
        return "\(now) · en \(month.formatted(.dateTime.month(.wide))) \(Int((first * 100).rounded())) %"
    }

    // MARK: Secciones

    @ViewBuilder
    private func booksSection(_ period: ReadingPeriod) -> some View {
        let books = period.books()
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Libros")
                ForEach(books, id: \.bookID) { entry in
                    if let book = model.shelfBook(id: entry.bookID.uuidString) {
                        NavigationLink(value: book) {
                            BookRow(book: book, detail: "\(entry.sessions == 1 ? "1 sesión" : "\(entry.sessions) sesiones") · de \(Int((entry.from * 100).rounded())) % a \(Int((entry.to * 100).rounded())) %") {
                                Text(ReadingFormat.duration(entry.seconds)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionsSection(_ period: ReadingPeriod) -> some View {
        if !period.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Sesiones")
                ForEach(period.sessions.reversed()) { session in
                    NavigationLink(value: SessionRef(id: session.id)) {
                        SessionRow(session: session, bookTitle: title(of: session.bookID))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Libros que terminaste en el periodo (una sesión llegó al final).
    private func finished(_ period: ReadingPeriod) -> [ShelfBook] {
        let ids = Set(period.sessions.filter { $0.toFraction >= 0.99 }.map(\.bookID))
        return ids.compactMap { model.shelfBook(id: $0.uuidString) }
    }

    @ViewBuilder
    private func finishedSection(_ period: ReadingPeriod) -> some View {
        let books = finished(period)
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionLabel(text: "Terminados")
                CoverGrid {
                    ForEach(books) { book in
                        NavigationLink(value: book) { CoverCell(book: book) }.buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func title(of id: UUID) -> String? {
        model.shelfBook(id: id.uuidString)?.title
    }
}

/// «‹ 10 – 16 de noviembre ›»: el periodo y sus flechas.
private struct PeriodStepper: View {
    let title: String
    var roman = false
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void

    var body: some View {
        HStack {
            Button(action: back) { Image(systemName: "chevron.left").frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget) }
                .accessibilityLabel("Anterior")
            Spacer()
            if roman { SectionLabel(text: title) } else { Text(title).font(.subheadline).foregroundStyle(Theme.secondaryInk) }
            Spacer()
            Button(action: forward) { Image(systemName: "chevron.right").frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget) }
                .disabled(!canGoForward)
                .accessibilityLabel("Siguiente")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.secondaryInk)
    }
}

/// «2 h 33 min» y «38 mil palabras · 6 sesiones · 5 de 7 días».
private struct PeriodTotal: View {
    let period: ReadingPeriod
    let days: Int
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(ReadingFormat.duration(period.readingSeconds))
                .font(.screenTitle)
            Text("\(ReadingFormat.words(period.words)) palabras · \(period.sessions.count == 1 ? "1 sesión" : "\(period.sessions.count) sesiones") · \(period.days(calendar: calendar)) de \(days) días")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
        }
    }
}

/// Una sesión pasada: sus números, sus etapas y lo que subrayaste en ella.
struct SessionScreen: View {
    let ref: SessionRef
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = SessionStore.shared
    @State private var notice: String?

    private var session: ReadingSession? { store.sessions.first { $0.id == ref.id } }

    var body: some View {
        ScrollView {
            if let session {
                let book = model.shelfBook(id: session.bookID.uuidString)
                let highlights = model.annotations.annotations(forBook: session.bookID)
                    .filter { $0.createdAt >= session.start && $0.createdAt <= session.end }
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    if let book {
                        NavigationLink(value: book) {
                            BookRow(book: book, detail: session.start.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                        }
                        .buttonStyle(.plain)
                    }
                    SessionDetail(session: session, bookTitle: book?.title ?? "", fraction: session.toFraction) {
                        notice = SessionNote.write(session, bookTitle: book?.title ?? "Sin título")
                    }
                    if !highlights.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            SectionLabel(text: "Subrayaste")
                            ForEach(highlights) { QuoteBlock(text: $0.quote, note: $0.note) }
                        }
                    }
                }
                .screenContent()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ShareSessionButton(card: ShareCard(session: session, title: book?.title ?? "", author: book?.author ?? "",
                                                           quote: highlights.first?.quote))
                    }
                }
            } else {
                EmptyState(title: "Sesión no encontrada", message: "Puede que aún no llegue de tu otro dispositivo.")
                    .screenContent()
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Nota", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }
}
