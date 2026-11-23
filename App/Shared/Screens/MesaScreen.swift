import LectoraCore
import SwiftUI

/// Mesa: el libro que estás leyendo y los siguientes en la pila.
struct MesaScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.bookOpeningNamespace) private var opening
    @ObservedObject private var sessions = SessionStore.shared
    /// Capturas automáticas: `-screenshot.screen diary` abre el diario.
    @State private var showsDiary = LaunchOptions.screen == "diary"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BrandMark()
                        .padding(.bottom, Theme.Space.xl)
                    Group {
                        if let book = model.currentBook {
                            current(book)
                        } else {
                            EmptyState(
                                title: "Tu biblioteca está vacía",
                                message: "Añade EPUB, PDF, MOBI o cómics. Leo sus datos, les busco portada y los guardo ordenados en una carpeta que Calibre también puede abrir.",
                                actionTitle: "Añadir libros",
                                action: { model.importing = true }
                            )
                        }
                    }
                }
                .screenContent()
            }
            .screen()
            .navigationDestination(isPresented: $showsDiary) { DiaryScreen() }
        }
    }

    private func current(_ book: ShelfBook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: model.continueReading) {
                ShelfCover(book: book).frame(width: Theme.Size.coverHero)
            }
            .buttonStyle(PressableStyle())
            .bookOpeningSource(in: opening)

            Text(book.title)
                .font(.bookTitle)
                .padding(.top, Theme.Space.xl)
            Text(book.author)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, Theme.Space.xs)

            if let sentence = book.lastSentence {
                QuoteBlock(label: "Donde lo dejaste", text: sentence, italic: true)
                    .padding(.top, Theme.Space.l)
            }

            ThinProgress(value: book.progress)
                .padding(.top, Theme.Space.xl)
            HStack {
                Text(progressLine(book))
                Spacer()
                Text(book.note ?? "")
            }
            .font(.footnote)
            .foregroundStyle(Theme.secondaryInk)
            .padding(.top, Theme.Space.s)

            HStack(spacing: Theme.Space.m) {
                PrimaryButton(title: book.progress > 0 ? "Seguir leyendo" : "Empezar a leer", action: model.continueReading)
                if Features.audiobook {
                    RoundIconButton(systemImage: "headphones", label: "Escuchar como audiolibro") {
                        withAnimation(Theme.Motion.standard) { model.listening = model.listening == nil ? book : nil }
                    }
                }
            }
            .padding(.top, Theme.Space.xl)

            weekSection
                .padding(.top, Theme.Space.xxl)

            if !model.desk.isEmpty {
                SectionLabel(text: "En la mesa")
                    .padding(.top, Theme.Space.xxl)
                    .padding(.bottom, Theme.Space.m)
                CoverGrid {
                    ForEach(model.desk.prefix(Theme.Size.gridColumns)) { item in
                        NavigationLink(value: item) { CoverCell(book: item, caption: item.caption) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    /// «57 % leído · te faltan ~3 h»; sin empezar, solo lo que dura («~15 h de lectura»):
    /// «0 % leído» junto a «Listo para leer» y «Seguir leyendo» se contradecía.
    private func progressLine(_ book: ShelfBook) -> String {
        let remaining = book.bookID.flatMap { sessions.remaining(forBook: $0, progress: book.progress) }
        guard book.progress > 0 else { return remaining.map { "~\(ReadingFormat.duration($0)) de lectura" } ?? "" }
        let percent = "\(book.progress.percentText) leído"
        guard let remaining else { return percent }
        return "\(percent) · te faltan ~\(ReadingFormat.duration(remaining))"
    }

    /// «Esta semana»: tu tiempo, tus días y la entrada al diario.
    @ViewBuilder
    private var weekSection: some View {
        if !sessions.sessions.isEmpty {
            let week = sessions.week()
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "Esta semana")
                    Spacer()
                    NavigationLink(value: DiaryRef()) {
                        Label("Diario", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                    Text(ReadingFormat.duration(week.period.readingSeconds))
                        .font(.bookTitle)
                    Text("\(ReadingFormat.words(week.period.words)) palabras · \(week.period.days()) días")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
                WeekBars(days: week.days)
                if let longest = week.period.longest, longest.readingSeconds >= 20 * 60,
                   let book = model.shelfBook(id: longest.bookID.uuidString) {
                    Text("El \(longest.start.es(.dateTime.weekday(.wide))) leíste \(ReadingFormat.duration(longest.readingSeconds)) seguidos de \(book.title): tu sesión más larga de la semana.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }
}
