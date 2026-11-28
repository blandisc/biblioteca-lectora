import LectoraCore
import SwiftUI

/// Ficha de un libro: portada, datos, sinopsis, leer y editar.
struct BookDetailScreen: View {
    let book: ShelfBook
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var sessionStore = SessionStore.shared
    @State private var editing = false
    @State private var searching = false
    @State private var choosingCover = false
    @Environment(\.windowLayout) private var window

    /// Datos al día: después de editar, la ficha se actualiza sola.
    private var live: ShelfBook { model.shelfBook(id: book.id) ?? book }
    private var record: Book? { model.book(for: live) }

    var body: some View {
        // La ficha como pliego: el libro (portada, título y «Empezar a leer») y sus datos. Una bajo
        // otra en un iPhone; acostado, lado a lado (el botón ya no queda fuera de la vista); en el
        // Duo abierto, cada una en su página, nunca la portada sobre el pliegue.
        Spread(spacing: Theme.Space.xl) {
            VStack(spacing: Theme.Space.l) {
                ShelfCover(book: live)
                    .frame(width: window.isShort ? Theme.Size.coverHeroShort : Theme.Size.coverDetail)
                    .padding(.top, window.isShort ? 0 : Theme.Space.l)
                VStack(spacing: Theme.Space.xs) {
                    // Número de ficha, como el id de Calibre que da nombre a la carpeta.
                    // En una ventana baja el número cede su renglón: «Empezar a leer» se veía a medias.
                    if let number = record?.calibreID, !window.isShort {
                        SectionLabel(text: "Nº \(number)")
                    }
                    WholeWordsText(live.title)
                        .font(.bookTitle)
                        .multilineTextAlignment(.center)
                        // En una ventana baja, a lo más tres renglones: con seis, «Empezar a leer»
                        // quedaba fuera de la vista (ronda 1, el Duo cerrado acostado).
                        .lineLimit(window.isShort ? Theme.Size.titleLinesShort : nil)
                    WholeWordsText(live.author)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(window.isShort ? 1 : nil)
                    if let series = live.series {
                        DotLine(parts: [series.isolated] + (live.seriesIndex.flatMap(ShelfBook.number).map { ["libro \($0)"] } ?? []),
                                alignment: .center)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                // Autor y serie centrados bajo el título, también cuando usan dos renglones.
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                if live.file != nil {
                    PrimaryButton(title: live.state.openAction, fillsWidth: true) {
                        model.open(live)
                    }
                } else {
                    Text("Aún no está en este dispositivo")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        } trailing: {
            VStack(spacing: Theme.Space.l) {
                if let record {
                    BookFacts(book: record)
                }

                readingSection
                    .padding(.top, Theme.Space.l)
                notesSection
                    .padding(.top, Theme.Space.l)
                highlightsSection
            }
        }
        .pushedScreen()
        .toolbar {
            if record != nil {
                ToolbarItem(placement: .primaryAction) {
                    BarMenu(title: "Editar") {
                        Button { editing = true } label: { Label("Escribir a mano", systemImage: "pencil") }
                        Button { searching = true } label: { Label(LibraryAction.findData.title, systemImage: LibraryAction.findData.symbol) }
                        Button { choosingCover = true } label: { Label("Elegir portada de internet", systemImage: "photo.on.rectangle") }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $searching) {
            if let id = live.bookID { CandidatesScreen(bookID: id, searchesFirst: true) }
        }
        // Capturas: `-screenshot.screen edit` abre «Escribir a mano» sobre la ficha; `candidates`,
        // «Buscar con otros datos», y `cover`, «Elegir portada de internet».
        .onAppear {
            switch LaunchOptions.screen {
            case "edit": editing = true
            case "candidates": searching = true
            case "cover": choosingCover = true
            default: break
            }
        }
        // En un pliego, en una página: la ficha sigue a la vista o, si la ficha es la página
        // derecha (lista | detalle), en esa misma.
        .sidePanel(isPresented: $editing) {
            if let record { MetadataEditorView(book: record) }
        }
        .sidePanel(isPresented: $choosingCover) {
            if let id = live.bookID { CoverPickerSheet(bookID: id) }
        }
    }
}

/// Portadas de internet para un libro, en cuadrícula: eliges una y listo.
extension BookDetailScreen {
    /// «Lectura»: cuánto le has dedicado, cuánto falta, tu ritmo y sus sesiones.
    @ViewBuilder
    private var readingSection: some View {
        let sessions = live.bookID.map { sessionStore.sessions(forBook: $0) } ?? []
        if !sessions.isEmpty {
            let period = ReadingPeriod(sessions)
            let remaining = live.bookID.flatMap { sessionStore.remaining(forBook: $0, progress: live.progress) }
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionHeader("Lectura")
                StatTrio(items: [
                    .init(value: ReadingFormat.duration(period.readingSeconds), label: "leído"),
                    .init(value: remaining.map { "~" + ReadingFormat.duration($0) } ?? "—", label: "te faltan"),
                    .init(value: period.wordsPerMinute.map(String.init) ?? "—", label: "palabras/min"),
                ])
                StageBar(segments: sessions.flatMap(\.segments))
                Text("\(period.immersedShare.percentText) del tiempo inmersa")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryInk)
                VStack(spacing: 0) {
                    ForEach(sessions.reversed().prefix(Theme.Lists.detailSessions)) { session in
                        NavigationLink(value: SessionRef(id: session.id)) { SessionRow(session: session) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Notas que enlazan este libro con `[[Título]]`, y «Nota nueva» ya enlazada.
    private var notesSection: some View {
        let notes = model.notes.notes(linking: live.title)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Notas") {
                NavigationLink(value: NoteRef.new(draft: "# \n\n[[\(live.title)]] ")) {
                    Text("Nota nueva").fontWeight(.medium).foregroundStyle(Theme.ink)
                        .frame(minHeight: Theme.Size.tapTarget)
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline)
            if notes.isEmpty {
                Text("Ninguna nota enlaza este libro todavía.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, Theme.Space.s)
            } else {
                ForEach(notes) { note in
                    NavigationLink(value: NoteRef(fileName: note.fileName)) {
                        NoteRow(note: note, detail: Self.quoteCount(note, title: live.title))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Los subrayados del libro, los primeros tres.
    @ViewBuilder
    private var highlightsSection: some View {
        let highlights = live.bookID.map { model.annotations.annotations(forBook: $0) } ?? []
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionHeader(highlights.count.counted("subrayado", "subrayados"))
                ForEach(highlights.prefix(Theme.Reader.foundHighlights)) { highlight in
                    QuoteBlock(text: highlight.quote, note: highlight.note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// «1 cita» o «3 citas» de este libro en la nota; si no tiene, nada.
    private static func quoteCount(_ note: Note, title: String) -> String? {
        let marker = "[[\(title)]] · [ir al pasaje]"
        let count = note.text.components(separatedBy: marker).count - 1
        guard count > 0 else { return nil }
        return count.counted("cita", "citas")
    }
}

struct CoverPickerSheet: View {
    let bookID: UUID
    @EnvironmentObject private var model: AppModel
    /// Cierra la hoja o, en un pliego, su panel (`SidePanel`).
    private let dismiss = SheetDismiss()
    @State private var options: [URL] = []
    @State private var choice: CoverChoiceRow.Option?
    @State private var loading = true
    @State private var saving = false
    @State private var errorMessage: String?

    private var current: URL? { model.library.book(id: bookID).flatMap { model.library.coverURL(for: $0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if options.isEmpty, loading {
                        LoadingLine(text: "Buscando portadas…")
                            .padding(.vertical, Theme.Space.xl)
                    } else if options.isEmpty {
                        EmptyState(title: "Sin portadas", message: "No encontré portadas de este libro en internet.")
                    } else {
                        Text("Primero las de ediciones en el idioma del libro.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                        // Las que ya bajaron, sin esperar a las demás (auditoría 9, B2).
                        CoverGrid {
                            ForEach(allOptions, id: \.self) { option in
                                CoverChoiceCell(option: option, selection: $choice)
                            }
                        }
                        .padding(.top, Theme.Space.l)
                        if loading {
                            LoadingLine(text: "Buscando más portadas…")
                                .padding(.vertical, Theme.Space.l)
                        }
                    }
                }
                .screenContent()
            }
            .pushedScreen("Portada", sheet: true)
            .sheetActions(leave: SheetAction(title: "Dejar la portada") { dismiss() },
                          confirm: SheetAction(title: saving ? "Guardando…" : "Usar esta portada",
                                               disabled: saving || !choosesRemote) { save() })
        }
        .task {
            choice = current.map { .current($0) }
            await model.library.coverOptions(for: bookID) { found in
                options = found
                if choice == nil { choice = found.first.map { .remote($0) } }
            }
            loading = false
        }
        .errorAlert("No pude cambiar la portada", message: $errorMessage, back: "Elegir otra portada")
    }

    private var allOptions: [CoverChoiceRow.Option] {
        (current.map { [.current($0)] } ?? []) + options.map { .remote($0) }
    }

    private var choosesRemote: Bool {
        if case .remote = choice { return true }
        return false
    }

    private func save() {
        guard case .remote(let url) = choice else { return }
        saving = true
        Task {
            do {
                try await model.library.setCover(url, for: bookID)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            saving = false
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
            rows.append(("Idioma", BookFields.languageName(language)))
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
