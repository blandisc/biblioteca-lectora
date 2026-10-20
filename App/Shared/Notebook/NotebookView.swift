import SwiftUI

/// Cuaderno (v7-Cuaderno): tus subrayados para repasar, por libro y por tema.
/// Datos de ejemplo hasta que entren LectoraCore y Readwise.
struct NotebookView: View {
    enum Part: String, CaseIterable, Identifiable {
        case review = "Repaso"
        case books = "Libros"
        case topics = "Temas"
        var id: Self { self }
    }

    @State private var section: Part = .review

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Sección", selection: $section) {
                        ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch section {
                    case .review: ReviewList()
                    case .books: BooksList()
                    case .topics: TopicsList()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Theme.groupedBackground.ignoresSafeArea())
            .navigationTitle("Cuaderno")
        }
    }
}

private struct SampleHighlight: Identifiable {
    let id = UUID()
    let text: String
    let book: String
    let note: String?
}

private let sampleHighlights = [
    SampleHighlight(text: "La libertad, Sancho, es uno de los más preciosos dones que a los hombres dieron los cielos.",
                    book: "Don Quijote de la Mancha", note: nil),
    SampleHighlight(text: "Nada de lo que acontece es contrario a la naturaleza de quien lo padece.",
                    book: "Meditaciones", note: "Releer antes de la reunión del lunes."),
    SampleHighlight(text: "Nothing in life is as important as you think it is, while you are thinking about it.",
                    book: "Pensar rápido, pensar despacio", note: nil),
]

private struct ReviewList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Para hoy · \(sampleHighlights.count) subrayados")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.horizontal, 4)
            ForEach(sampleHighlights) { highlight in
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlight.text)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(3)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.pencil).frame(width: 3)
                        }
                    if let note = highlight.note {
                        Label(note, systemImage: "pencil")
                            .font(.footnote)
                            .foregroundStyle(Theme.pencil)
                    }
                    Text(highlight.book)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            }
        }
    }
}

private struct BooksList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(SampleLibrary.books.filter { $0.progress > 0 }.enumerated()), id: \.element.id) { index, book in
                if index > 0 { Divider().padding(.leading, 74) }
                HStack(spacing: 14) {
                    ShelfCover(book: book).frame(width: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title).font(.body.weight(.semibold)).lineLimit(1)
                        Text(book.author).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer(minLength: 0)
                    Text("\(Int(book.progress * 40) + 3)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.pencil)
                        .accessibilityLabel("subrayados")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

private struct TopicsList: View {
    private let topics = [("Libertad", 14), ("Atención", 9), ("Estoicismo", 22), ("Memoria", 6), ("Decisiones", 11)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agrupados en tu dispositivo a partir de tus subrayados.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                    if index > 0 { Divider().padding(.leading, 16) }
                    HStack {
                        Text(topic.0).font(.body)
                        Spacer()
                        Text("\(topic.1)").monospacedDigit().foregroundStyle(Theme.secondaryInk)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }
}
