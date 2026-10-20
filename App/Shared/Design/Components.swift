import SwiftUI
import LectoraCore

/// Barra de progreso fina (4 pt en la tarjeta, 2 pt bajo las portadas).
struct ThinProgress: View {
    let value: Double
    var height: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(Theme.track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Progreso")
            .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

/// Respuesta al toque: se hunde un poco, sin cambiar de color.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Portada con la nube cuando el libro no está descargado.
struct ShelfCover: View {
    let book: ShelfBook
    var showsRibbon = false

    var body: some View {
        CoverView(title: book.title, author: book.author, style: book.cover, showsRibbon: showsRibbon, image: book.coverImage)
            .overlay(alignment: .bottomTrailing) {
                if book.inCloudOnly {
                    Image(systemName: "icloud")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(5)
                        .background(.regularMaterial, in: Circle())
                        .padding(5)
                        .accessibilityLabel("En iCloud")
                }
            }
    }
}

/// Ficha de un libro: portada, datos, sinopsis, leer y editar.
struct BookDetailView: View {
    let book: ShelfBook
    @EnvironmentObject private var model: AppModel
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .editorial
    @State private var editing = false

    /// Datos al día: después de editar, la ficha se actualiza sola.
    private var live: ShelfBook { model.shelf.first { $0.id == book.id } ?? book }
    private var record: Book? { model.book(for: live) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ShelfCover(book: live)
                    .frame(width: 168)
                    .padding(.top, 12)
                VStack(spacing: 4) {
                    Text(live.title)
                        .font(.serifTitle(26))
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
                Button {
                    model.open(live)
                } label: {
                    Text(live.file != nil ? (live.isReading ? "Seguir leyendo" : "Leer") : "Aún no está en este dispositivo")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(live.file != nil ? Theme.onInk : Theme.secondaryInk)
                        .background(live.file != nil ? Theme.ink : Theme.track,
                                    in: RoundedRectangle(cornerRadius: style == .editorial ? Theme.Editorial.buttonRadius : 24, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .disabled(live.file == nil)
                .padding(.horizontal, 24)

                if let record {
                    BookFacts(book: record)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background((style == .editorial ? Theme.Editorial.paper : Theme.groupedBackground).ignoresSafeArea())
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

/// Datos del libro en filas: lo que se ve en Calibre, sin ruido.
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
        VStack(alignment: .leading, spacing: 18) {
            if let summary = book.summary.map(Self.plainText), !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(3)
            }
            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { label, value in
                    HStack(alignment: .firstTextBaseline) {
                        Text(label).foregroundStyle(Theme.secondaryInk)
                        Spacer(minLength: 16)
                        Text(value).multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.track).frame(height: 0.5) }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
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
