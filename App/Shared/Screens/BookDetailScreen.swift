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

    /// Datos al día: después de editar, la ficha se actualiza sola.
    private var live: ShelfBook { model.shelfBook(id: book.id) ?? book }
    private var record: Book? { model.book(for: live) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                ShelfCover(book: live)
                    .frame(width: Theme.Size.coverDetail)
                    .padding(.top, Theme.Space.l)
                VStack(spacing: Theme.Space.xs) {
                    // Número de ficha, como el id de Calibre que da nombre a la carpeta.
                    if let number = record?.calibreID {
                        SectionLabel(text: "Nº \(number)")
                    }
                    Text(live.title)
                        .font(.bookTitle)
                        .multilineTextAlignment(.center)
                    Text(live.author)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                    if let series = live.series {
                        Text(live.seriesIndex.flatMap(ShelfBook.number).map { "\(series) · libro \($0)" } ?? series)
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

                readingSection
                    .padding(.top, Theme.Space.l)
                notesSection
                    .padding(.top, Theme.Space.l)
                highlightsSection
            }
            .screenContent()
        }
        .pushedScreen()
        .toolbar {
            if record != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Editar") {
                        Button { editing = true } label: { Label("Escribir a mano", systemImage: "pencil") }
                        Button { searching = true } label: { Label("Buscar datos en internet", systemImage: "globe") }
                        Button { choosingCover = true } label: { Label("Elegir portada de internet", systemImage: "photo.on.rectangle") }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $searching) {
            if let id = live.bookID { CandidatesScreen(bookID: id, searchesFirst: true) }
        }
        .sheet(isPresented: $editing) {
            if let record { MetadataEditorView(book: record) }
        }
        .sheet(isPresented: $choosingCover) {
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
                SectionLabel(text: "Lectura")
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
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Notas")
                Spacer()
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
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "Subrayados")
                    Spacer()
                    Text("\(highlights.count)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
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
    @Environment(\.dismiss) private var dismiss
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
                    if loading {
                        HStack(spacing: Theme.Space.l) {
                            ProgressView()
                            Text("Buscando portadas…").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(.vertical, Theme.Space.xl)
                    } else if options.isEmpty {
                        EmptyState(title: "Sin portadas", message: "No encontré portadas de este libro en internet.")
                    } else {
                        Text("Primero las de ediciones en el idioma del libro.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                        CoverGrid {
                            ForEach(allOptions, id: \.self) { option in
                                CoverChoiceCell(option: option, selection: $choice)
                            }
                        }
                        .padding(.top, Theme.Space.l)
                    }
                }
                .screenContent()
            }
            .pushedScreen("Portada")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dejar la portada") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Guardando…" : "Usar") { save() }
                        .disabled(saving || !choosesRemote)
                }
            }
        }
        .task {
            options = await model.library.coverOptions(for: bookID)
            choice = current.map { .current($0) } ?? options.first.map { .remote($0) }
            loading = false
        }
        .alert("No se pudo cambiar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Elegir otra portada", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
