import SwiftUI

/// Mesa: el libro que estás leyendo y los siguientes en la pila.
struct MesaScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.bookOpeningNamespace) private var opening

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
                .padding(.top, Theme.Space.xl + Theme.Space.xs)
            Text(book.author)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, Theme.Space.xs)

            if let sentence = book.lastSentence {
                QuoteBlock(label: "Donde lo dejaste", text: sentence, italic: true)
                    .padding(.top, Theme.Space.l + Theme.Space.xxs)
            }

            ThinProgress(value: book.progress)
                .padding(.top, Theme.Space.xl)
            HStack {
                Text("\(Int(book.progress * 100)) % leído")
                Spacer()
                Text(book.note ?? "")
            }
            .font(.footnote)
            .foregroundStyle(Theme.secondaryInk)
            .padding(.top, Theme.Space.s)

            HStack(spacing: Theme.Space.m) {
                PrimaryButton(title: "Seguir leyendo", action: model.continueReading)
                RoundIconButton(systemImage: "headphones", label: "Escuchar como audiolibro") {
                    withAnimation(Theme.Motion.standard) { model.listening = model.listening == nil ? book : nil }
                }
            }
            .padding(.top, Theme.Space.xl)

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
}
