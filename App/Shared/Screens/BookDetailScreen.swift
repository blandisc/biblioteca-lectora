import LectoraCore
import SwiftUI

/// Ficha de un libro: portada, datos, sinopsis, leer y editar.
struct BookDetailScreen: View {
    let book: ShelfBook
    @EnvironmentObject private var model: AppModel
    @State private var editing = false

    /// Datos al día: después de editar, la ficha se actualiza sola.
    private var live: ShelfBook { model.shelfBook(id: book.id) ?? book }
    private var record: Book? { model.book(for: live) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                ShelfCover(book: live)
                    .frame(width: Theme.Size.coverDetail)
                    .padding(.top, Theme.Space.m)
                VStack(spacing: Theme.Space.xs) {
                    Text(live.title)
                        .font(.bookTitle)
                        .multilineTextAlignment(.center)
                    Text(live.author)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                    if let series = live.series {
                        Text(live.seriesIndex.map { "\(series) · libro \(ShelfBook.number($0))" } ?? series)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity)

                if live.file != nil {
                    PrimaryButton(title: live.isReading ? "Seguir leyendo" : "Leer", fillsWidth: true) {
                        model.open(live)
                    }
                } else {
                    Text("Aún no está en este dispositivo")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }

                if let record {
                    BookFacts(book: record)
                        .padding(.top, Theme.Space.s)
                }
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if record != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") { editing = true }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let record { MetadataEditorView(book: record) }
        }
    }
}

/// Sinopsis y datos del libro en filas, sin ruido.
private struct BookFacts: View {
    let book: Book

    private var rows: [(String, String)] {
        var rows: [(String, String)] = []
        if let published = book.published { rows.append(("Publicado", published)) }
        if let publisher = book.publisher { rows.append(("Editorial", publisher)) }
        if let language = book.language {
            rows.append(("Idioma", Locale(identifier: "es").localizedString(forLanguageCode: language)?.capitalized ?? language))
        }
        if let isbn = book.identifiers["isbn"] { rows.append(("ISBN", isbn)) }
        if !book.tags.isEmpty { rows.append(("Etiquetas", book.tags.joined(separator: ", "))) }
        if let path = book.filePath { rows.append(("Archivo", (path as NSString).pathExtension.uppercased())) }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if let summary = book.summary.map(Self.plainText), !summary.isEmpty {
                Text(summary)
                    .font(.prose)
                    .lineSpacing(Theme.Space.xs)
                    .foregroundStyle(Theme.ink)
            }
            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { label, value in
                    FactRow(label: label, value: value)
                }
            }
        }
    }

    /// Las sinopsis de Calibre y de los EPUB suelen traer HTML.
    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<br\\s*/?>|</p>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
