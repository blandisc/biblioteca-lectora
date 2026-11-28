import LectoraCore
import SwiftUI

/// Mesa: el libro que estás leyendo y los siguientes en la pila.
struct MesaScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.bookOpeningNamespace) private var opening
    @ObservedObject private var sessions = SessionStore.shared
    /// Lo empujado (el Diario, una sesión, un libro de la mesa). Capturas: `-screenshot.screen diary`
    /// abre el Diario (en la Mac, con `-screenshot.tab desk`), ya puesta la Mesa: empezar con él no
    /// empujaba nada en la Mac, y con `navigationDestination(isPresented:)` a veces no salía (ronda 1).
    @State private var path = NavigationPath()
    @Environment(\.windowLayout) private var window

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let book = model.currentBook {
                    // El libro que lees y, de acompañante, tu semana y la mesa: una bajo otra en un
                    // iPhone; lado a lado acostado; en el Duo abierto, cada una en su página.
                    Spread(measured: false) {
                        DeskHeader()
                            .padding(.bottom, window.isShort ? Theme.Space.l : Theme.Space.xl)
                        reading(book)
                    } trailing: {
                        beside
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            DeskHeader()
                                .padding(.bottom, Theme.Space.xl)
                            // Con tu biblioteca todavía en iCloud no ofrezco añadir: la Biblioteca dice
                            // «Bajando tu biblioteca» y aquí también (auditoría 4).
                            LibraryEmptyState(kind: LibraryEmptyKind(waitingForCloud: model.library.waitingForCloud,
                                                                     cloudGaveUp: model.library.cloudGaveUp),
                                              add: { model.addBooks() }, welcome: { model.welcomeRequested = true })
                        }
                        .screenContent(wide: true)
                    }
                }
            }
            // Portadas nítidas: filo fino y sombra larga y tenue (ME-1).
            .environment(\.crispCovers, true)
            #if os(macOS)
            // En la Mac el nombre va en la barra (regla 8); la Mesa no tiene `ScreenHeading`.
            .navigationTitle("Mesa")
            #endif
            .screen()
            // En el pliego, lo empujado (el Diario, una sesión) trae su «atrás» arriba a la izquierda (D13-B).
            .environment(\.inFoldDetail, window.verticalFold != nil)
            #if DEBUG
            .task {
                guard LaunchOptions.screen == "diary" else { return }
                // En la Mac la Mesa se arma dos veces al abrir: se espera a que se quede quieta.
                try? await Task.sleep(for: .seconds(1))
                if path.isEmpty { path.append(DiaryRef()) }
            }
            #endif
        }
    }

    /// Tu semana y lo que espera en la mesa.
    private var beside: some View {
        VStack(alignment: .leading, spacing: 0) {
            weekSection

            if !model.desk.isEmpty {
                SectionHeader("En la mesa")
                    .padding(.top, sessions.sessions.isEmpty ? 0 : Theme.Space.xxl)
                    .padding(.bottom, Theme.Space.l)
                CoverGrid {
                    ForEach(model.desk.prefix(Theme.Size.gridColumns)) { item in
                        NavigationLink(value: item) { CoverCell(book: item, caption: item.caption) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func reading(_ book: ShelfBook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: model.continueReading) {
                // En una ventana baja, más chica: la portada no empuja «Seguir leyendo» fuera de la vista.
                ShelfCover(book: book).frame(width: window.isShort ? Theme.Size.coverHeroShort : Theme.Size.coverHero)
            }
            .buttonStyle(PressableStyle())
            .bookOpeningSource(in: opening)

            WholeWordsText(book.title)
                .font(.bookTitle)
                // En una ventana baja, a lo más tres renglones, como en la ficha.
                .lineLimit(window.isShort ? Theme.Size.titleLinesShort : nil)
                .padding(.top, Theme.Space.xl)
            Text(book.author)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, Theme.Space.xs)

            if let sentence = book.lastSentence {
                QuoteBlock(label: "Donde lo dejaste", text: sentence, hanging: true)
                    .padding(.top, Theme.Space.l)
            }

            ThinProgress(value: book.progress)
                .padding(.top, Theme.Space.xl)
            // Con la letra más grande, el avance y la nota uno bajo otro.
            // Sin empezar y sin cálculo, no hay avance que decir: el renglón vacío se estiraba
            // y apretaba la nota en una columna de cuatro renglones.
            AdaptiveStack(spacing: Theme.Space.xs) {
                let line = progressLine(book)
                if !line.isEmpty {
                    Text(line)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let note = book.note { Text(note) }
            }
            .font(.footnote)
            .foregroundStyle(Theme.secondaryInk)
            .padding(.top, Theme.Space.s)

            HStack(spacing: Theme.Space.l) {
                PrimaryButton(title: book.state.openAction, action: model.continueReading)
                if Features.audiobook {
                    RoundIconButton(systemImage: "headphones", label: "Escuchar como audiolibro") {
                        withAnimation(Theme.Motion.standard) { model.listening = model.listening == nil ? book : nil }
                    }
                }
            }
            .padding(.top, Theme.Space.xl)
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
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionHeader(title: "Esta semana") {
                    NavigationLink(value: DiaryRef()) {
                        Label("Diario", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(minHeight: Theme.Size.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.l) {
                    Text(ReadingFormat.duration(week.period.readingSeconds))
                        .font(.bookTitle)
                    Text("\(week.period.words.counted("palabra", "palabras", shown: ReadingFormat.words(week.period.words))) · \(week.period.days().counted("día", "días"))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
                WeekBars(days: week.days)
                if let longest = week.period.longest, longest.readingSeconds >= 20 * 60,
                   let book = model.shelfBook(id: longest.bookID.uuidString) {
                    Text("El \(longest.start.es(.dateTime.weekday(.wide))) leíste \(ReadingFormat.duration(longest.readingSeconds)) seguidos de \(book.title.isolated): tu sesión más larga de la semana.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }
}
