import LectoraCore
import SwiftUI

struct ReviewInboxRef: Hashable {}

struct FilledRef: Hashable {
    let bookID: UUID
}

struct CandidatesRef: Hashable {
    let bookID: UUID
    /// Buscar de nuevo al abrir (desde la ficha: «Buscar en internet»).
    var searchesFirst = false
}

/// «Por revisar»: los libros cuyos datos de internet no fueron seguros. Se resuelven uno
/// por uno o en lote (UX-5): completar de una vez los muy probables (solo se llena lo que
/// falta) o elegir varios y mantener sus datos. Todo lote pide confirmación y se deshace.
/// Es la misma pantalla en el iPhone y en la Mac.
struct ReviewScreen: View {
    @EnvironmentObject private var model: AppModel
    /// Elegir varios para mantener sus datos.
    @State private var choosing = false
    @State private var chosen = Set<UUID>()
    @State private var confirming: ReviewBatch?
    @State private var working = false
    /// Lo último que hice en lote, para deshacerlo.
    @State private var lastBatch: (text: String, undo: LibraryStore.ReviewUndo)?
    @State private var errorMessage: String?

    private var pending: [ShelfBook] {
        model.library.reviews.keys
            .compactMap { model.shelfBook(id: $0.uuidString) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Los que se pueden completar sin preguntar uno por uno.
    private var safe: [UUID] {
        pending.compactMap(\.bookID).filter { MetadataMatcher.isSafeSuggestion(model.library.reviews[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Por revisar")
                // La explicación solo si hay libros dudosos: sobre «Se completaron solos» confunde.
                if !pending.isEmpty {
                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.xs)
                }
                if let lastBatch {
                    UndoNotice(text: lastBatch.text) { undo(lastBatch.undo) }
                        .padding(.top, Theme.Space.l)
                        .transition(.opacity)
                }
                if !model.library.pendingLookup.isEmpty {
                    waiting.padding(.top, Theme.Space.l)
                }
                if working {
                    LoadingLine(text: "Completando los libros muy probables…")
                        .padding(.top, Theme.Space.l)
                }
                if pending.isEmpty && filled.isEmpty {
                    EmptyState(title: "Todo en orden", message: "No hay libros pendientes de revisar.")
                } else if !pending.isEmpty {
                    bulkActions.padding(.top, Theme.Space.s)
                    if choosing {
                        Text("Los que elijas se quedan con los datos que tienen ahora.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            .padding(.bottom, Theme.Space.s)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(pending) { book in
                            if let id = book.bookID { row(book, id) }
                        }
                    }
                }
                if !filled.isEmpty { filledSection }
            }
            .animation(Theme.Motion.standard, value: lastBatch?.text)
            .screenContent()
        }
        // «Mantener los datos de N libros» fijo abajo mientras eliges: al final de una lista
        // larga no se veía y había que bajar hasta él.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if choosing, !pending.isEmpty {
                BottomBar {
                    SecondaryButton(title: keepTitle(chosen.count), systemImage: "checkmark") {
                        confirming = .keep(Array(chosen))
                    }
                    .disabled(chosen.isEmpty)
                }
            }
        }
        .pushedScreen()
        .disabled(working)
        .question(confirming?.title ?? "", isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } }
        ), presenting: confirming) { batch in
            Button(batch.action) { run(batch) }
            Button("Dejarlos por revisar", role: .cancel) {}
        } message: { batch in
            Text(batch.message)
        }
        .errorAlert("No pude deshacer el cambio", message: $errorMessage, back: "Volver a la revisión")
        #if DEBUG
        // Capturas: `-screenshot.demo reviewConfirm` pide confirmar «Completar los muy probables»,
        // `reviewDone` los completa (y enseña «Deshacer»), `reviewChoose` elige el primero y
        // `reviewKeep` mantiene sus datos.
        .task {
            try? await Task.sleep(for: .seconds(1))
            let first = pending.prefix(1).compactMap(\.bookID)
            switch LaunchOptions.demo {
            case "reviewConfirm": confirming = .completeSafe(safe)
            case "reviewDone": run(.completeSafe(safe))
            case "reviewChoose": choosing = true; chosen = Set(first)
            case "reviewKeep": run(.keep(first))
            default: break
            }
        }
        #endif
    }

    /// Completar los muy probables y elegir varios, sobre la lista.
    private var bulkActions: some View {
        AdaptiveStack(spacing: Theme.Space.l) {
            if !choosing, !safe.isEmpty {
                TextAction(title: safe.count == 1 ? "Completar el muy probable" : "Completar los \(safe.count) muy probables") {
                    confirming = .completeSafe(safe)
                }
            }
            Spacer(minLength: 0)
            if choosing {
                TextAction(title: chosen.count == pending.count ? "Quitar la elección" : "Elegir todos") {
                    chosen = chosen.count == pending.count ? [] : Set(pending.compactMap(\.bookID))
                }
            }
            TextAction(title: choosing ? "Terminar de elegir" : "Elegir varios") {
                withAnimation(Theme.Motion.standard) {
                    choosing.toggle()
                    chosen = []
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ book: ShelfBook, _ id: UUID) -> some View {
        if choosing {
            Button {
                if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
            } label: {
                BookRow(book: book, detail: detail(for: id)) { ChoiceMark(selected: chosen.contains(id)) }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(chosen.contains(id) ? .isSelected : [])
        } else {
            NavigationLink(value: CandidatesRef(bookID: id)) {
                BookRow(book: book, detail: detail(for: id)) {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Lo de arriba dice lo que pasó con estos libros: los que encontré con dudas, los que no
    /// encontré o los dos (decía «Encontré estos libros» sobre filas «No lo encontré»).
    private var intro: String {
        let ids = pending.compactMap(\.bookID)
        let found = ids.filter { !(model.library.reviews[$0] ?? []).isEmpty }.count
        if found == ids.count {
            return "Encontré estos libros en internet, pero no estoy seguro de que sean los tuyos. Elige los datos correctos o conserva los que tienen."
        }
        if found == 0 {
            return "No encontré estos libros en internet. Busca con otro título, autor o ISBN, escribe sus datos a mano o conserva los que tienen."
        }
        return "De algunos encontré datos en internet, pero no estoy seguro de que sean los tuyos; otros no los encontré. Abre cada uno para elegir sus datos o conservar los que tienen."
    }

    private func keepTitle(_ count: Int) -> String {
        // Corto: con la letra más grande la barra ocupaba cuatro renglones (auditoría 8). Lo que
        // hace se explica arriba, sobre la lista.
        count == 0 ? "Elige los libros" : "Mantener los datos de \(count.counted("libro", "libros"))"
    }

    private func run(_ batch: ReviewBatch) {
        switch batch {
        case .completeSafe(let ids):
            working = true
            Task {
                let undo = await model.library.completeSafeReviews(ids)
                working = false
                lastBatch = (undo.completed.isEmpty
                    ? "Ya tenían todo: dejé \(undo.reviews.count.counted("libro", "libros")) como estaban."
                    : "Completé \(undo.completed.count.counted("libro", "libros")) con sus datos muy probables; los ves en «Lo que completé solo».", undo)
            }
        case .keep(let ids):
            let undo = model.library.dismissReviews(ids)
            choosing = false
            chosen = []
            lastBatch = ("Dejé \(undo.reviews.count.counted("libro", "libros")) con sus datos de siempre.", undo)
        }
    }

    private func undo(_ batch: LibraryStore.ReviewUndo) {
        do {
            try model.library.undo(batch)
            lastBatch = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    private var filled: [ShelfBook] {
        model.library.filled
            .sorted { $0.value.date > $1.value.date }
            .compactMap { model.shelfBook(id: $0.key.uuidString) }
    }

    /// Lo que se completó solo: para revisarlo de un vistazo y deshacer lo que no quieras.
    private var filledSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Lo que completé solo") {
                // Dice qué pasa: los das por buenos y salen de la lista («Todo bien» no lo decía).
                TextAction(title: "Darlos por buenos") { model.library.forgetAllFilled() }
            }
            Text("Datos que tomé de internet porque estaba seguro. Revísalos y deshaz lo que no quieras.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, Theme.Space.xs)
            LazyVStack(spacing: 0) {
                ForEach(filled) { book in
                    if let id = book.bookID, let record = model.library.filled[id] {
                        NavigationLink(value: FilledRef(bookID: id)) {
                            BookRow(book: book, detail: record.changes.map(\.field.label).joined(separator: ", ")) {
                                Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, Theme.Space.s)
        }
        .padding(.top, Theme.Space.xxl)
    }

    /// Libros que no se pudieron buscar por falta de conexión.
    private var waiting: some View {
        let count = model.library.pendingLookup.count
        return Button {
            Task { await model.library.retryPendingLookups() }
        } label: {
            LinkRow(title: count.counted("libro espera conexión", "libros esperan conexión"),
                    value: model.library.identifying.isEmpty ? "Buscar ahora" : "Buscando…")
        }
        .buttonStyle(.plain)
        .disabled(!model.library.identifying.isEmpty)
    }

    private func detail(for id: UUID) -> String {
        guard let candidates = model.library.reviews[id], let best = candidates.first else {
            return "No lo encontré en internet"
        }
        let count = candidates.count.counted("opción", "opciones")
        return "\(count) · \(best.verdict)"
    }
}

/// Lo que se hace en lote en «Por revisar», con lo que dice su confirmación.
enum ReviewBatch: Hashable {
    case completeSafe([UUID])
    case keep([UUID])

    private var count: String {
        switch self {
        case .completeSafe(let ids), .keep(let ids): ids.count.counted("libro", "libros")
        }
    }

    var title: String {
        switch self {
        case .completeSafe: "¿Completar \(count) con sus datos muy probables?"
        case .keep: "¿Mantener los datos de \(count)?"
        }
    }

    var message: String {
        switch self {
        case .completeSafe:
            "Solo lleno lo que les falta (autor, año, editorial, ISBN, sinopsis, portada): lo que ya tienen no cambia. Puedes deshacerlo aquí mismo o dato por dato en «Lo que completé solo»."
        case .keep:
            "Salen de «Por revisar» sin cambiar nada. Puedes deshacerlo aquí mismo."
        }
    }

    var action: String {
        switch self {
        case .completeSafe: "Completar \(count)"
        case .keep: "Mantener los datos de \(count)"
        }
    }
}

/// Elegir entre los libros encontrados (con vista previa de lo que cambia),
/// buscar con otros datos, conservar los tuyos o escribirlos a mano.
struct CandidatesScreen: View {
    let bookID: UUID
    var searchesFirst = false
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewing: MetadataCandidate?
    @State private var editing = false
    @State private var searchingOther = false
    @State private var unreachable = false
    /// Lo encontré pero no lo pude guardar: otro trabajo corre (mover el Gabinete). No es «sin conexión».
    @State private var busyReason: String?
    /// Lo que vuelvo a buscar en cuanto termine el trabajo que corre.
    @State private var pendingAsk: Ask?
    /// Cada vez que me encuentro ocupado, una espera nueva (aunque sea lo mismo).
    @State private var waits = 0
    /// Ya lo estaba buscando (la vuelta de lo pendiente o el lote): espero ese resultado (auditoría 8, B2).
    @State private var alreadySearching = false

    private var book: ShelfBook? { model.shelfBook(id: bookID.uuidString) }
    private var candidates: [MetadataCandidate] { model.library.reviews[bookID] ?? [] }
    private var searching: Bool { model.library.identifying.contains(bookID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Elige los datos")
                if let book {
                    Text("Tus datos ahora")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.l)
                    BookRow(book: book, detail: book.author)
                }

                Group {
                    if searching {
                        LoadingLine(text: alreadySearching ? Self.alreadySearchingLine : "Buscando en internet…")
                            .padding(.vertical, Theme.Space.xl)
                    } else if let busyReason {
                        EmptyState(title: "Espera un momento",
                                   message: "\(busyReason) En cuanto termine, lo vuelvo a buscar solo.")
                    } else if unreachable {
                        EmptyState(title: "Sin conexión",
                                   message: "No pude preguntar en internet. Lo intento de nuevo cuando vuelvas a abrir la app, o ahora:")
                        SecondaryButton(title: "Intentar de nuevo", systemImage: "arrow.clockwise") { Task { await research() } }
                            .padding(.top, Theme.Space.l)
                    } else if candidates.isEmpty {
                        EmptyState(title: "No lo encontré",
                                   message: "Prueba con otro título, autor o ISBN, o escribe los datos a mano.")
                    } else {
                        Text("Encontrados en internet")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                            .padding(.top, Theme.Space.xl)
                        LazyVStack(spacing: 0) {
                            ForEach(candidates) { candidate in
                                Button { previewing = candidate } label: {
                                    CandidateRow(candidate: candidate)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Muestra qué cambiaría en tu libro")
                            }
                        }
                    }
                }

                VStack(spacing: Theme.Space.l) {
                    SecondaryButton(title: "Buscar con otros datos", systemImage: "magnifyingglass") { searchingOther = true }
                    SecondaryButton(title: "Escribir a mano", systemImage: "pencil") { editing = true }
                    SecondaryButton(title: "Mantener mis datos") {
                        model.library.dismissReview(bookID)
                        dismiss()
                    }
                }
                .padding(.top, Theme.Space.xl)
                .disabled(searching)
            }
            .screenContent()
        }
        .pushedScreen()
        .task {
            if searchesFirst { await research() }
        }
        .task(id: waits) {
            guard let ask = pendingAsk else { return }
            await model.library.waitUntilIdle()
            guard !Task.isCancelled else { return }
            show(await run(ask), asked: ask)
        }
        .sheet(item: $previewing) { candidate in
            CandidatePreview(bookID: bookID, candidate: candidate) { dismiss() }.duoBars()
        }
        .sheet(isPresented: $searchingOther) {
            if let record = model.library.book(id: bookID) {
                OtherSearchSheet(book: record) { title, author, isbn in
                    Task {
                        let ask = Ask.other(title: title, author: author, isbn: isbn)
                        show(await run(ask), asked: ask)
                    }
                }
                .duoBars()
            }
        }
        .sheet(isPresented: $editing) {
            if let record = model.library.book(id: bookID) { MetadataEditorView(book: record).duoBars() }
        }
    }

    private func research() async {
        show(await run(.again), asked: .again)
    }

    /// Lo que pediste buscar: lo mismo otra vez o con otros datos.
    enum Ask: Equatable {
        case again
        case other(title: String, author: String?, isbn: String?)
    }

    /// Lo que digo mientras espero la búsqueda que ya corría de este libro.
    static let alreadySearchingLine = "Ya lo estoy buscando; en cuanto termine te enseño lo que encontré…"

    private func run(_ ask: Ask) async -> MetadataService.Decision? {
        // Ya lo estaba buscando (auditoría 8, B2): antes `identify` devolvía nil, el «Buscando» se
        // quitaba y no salía nada. Espero esa búsqueda; si dejó candidatos, te los enseño, y si no
        // (completó lo seguro o no lo encontró), busco lo que pediste.
        if model.library.identifying.contains(bookID) {
            alreadySearching = true
            await model.library.waitUntilSearched(bookID)
            alreadySearching = false
            if Task.isCancelled { return nil }
            if ask == .again, !candidates.isEmpty { return .review }
        }
        switch ask {
        case .again: return await model.library.identify(bookID, askAlways: true)
        case .other(let title, let author, let isbn): return await model.library.search(title: title, author: author, isbn: isbn, for: bookID)
        }
    }

    /// Sin conexión y ocupado son dos cosas (auditoría 6): cada una con sus palabras. Ocupado (un
    /// trabajo de toda la biblioteca), espero a que termine y lo vuelvo a buscar solo (auditoría 7).
    private func show(_ decision: MetadataService.Decision?, asked: Ask) {
        unreachable = decision == .unreachable
        busyReason = decision == .busy ? (model.library.busyReason ?? LibraryWork.moving.reason) : nil
        pendingAsk = decision == .busy ? asked : nil
        if decision == .busy { waits += 1 }
    }
}

/// Vista previa de un candidato: qué cambiaría en tu libro, campo por campo,
/// y si quieres también su portada.
struct CandidatePreview: View {
    let bookID: UUID
    @State var candidate: MetadataCandidate
    /// Al aplicar, también se cierra la pantalla de candidatos.
    let onApplied: () -> Void
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var coverOptions: [CoverChoiceRow.Option] = []
    @State private var coverChoice: CoverChoiceRow.Option?
    @State private var loadingCovers = true
    @State private var applying = false
    @State private var errorMessage: String?

    private var book: Book? { model.library.book(id: bookID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        CandidateCover(candidate: candidate, width: Theme.Size.coverEditor)
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            WholeWordsText(candidate.title).font(.rowTitle).foregroundStyle(Theme.ink)
                            Text(candidate.authors.first ?? "").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                            Text("\(candidate.verdict) · \(candidate.source.rawValue)")
                                .font(.caption)
                                .foregroundStyle(Theme.tertiaryInk)
                            if !candidate.reasons.isEmpty {
                                Text(candidate.reasons).font(.caption).foregroundStyle(Theme.tertiaryInk)
                            }
                        }
                    }

                    Text("Portada")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.xl)
                    if loadingCovers {
                        LoadingLine(text: "Buscando portadas…").padding(.vertical, Theme.Space.l)
                    } else if coverOptions.isEmpty {
                        Text("No encontré portadas en internet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                            .padding(.top, Theme.Space.xs)
                    } else {
                        CoverChoiceRow(options: coverOptions, selection: $coverChoice)
                    }

                    Text("Lo que cambia")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.xl)
                    if let preview {
                        CompareRow(label: "Título", new: preview.title, old: book?.title)
                        CompareRow(label: "Autor", new: preview.authors.first, old: book?.authors.first)
                        CompareRow(label: "Publicado", new: preview.published, old: book?.published)
                        CompareRow(label: "Editorial", new: preview.publisher, old: book?.publisher)
                        CompareRow(label: "Idioma", new: preview.language.map(BookFields.languageName),
                                   old: book?.language.map(BookFields.languageName))
                        CompareRow(label: "ISBN", new: preview.identifiers["isbn"], old: book?.identifiers["isbn"])
                        CompareRow(label: "Serie", new: preview.series.map { name in
                            preview.seriesIndex.flatMap(ShelfBook.number).map { "\(name.isolated) · \($0)" } ?? name
                        }, old: book?.series)
                        CompareRow(label: "Géneros", new: preview.tags.joined(separator: ", "), old: book?.tags.joined(separator: ", "))
                    }

                    if let summary = candidate.summary {
                        QuoteBlock(label: "Sinopsis", text: summary)
                            .padding(.top, Theme.Space.xl)
                    } else if candidate.workKey != nil {
                        LoadingLine(text: "Buscando la sinopsis…").padding(.top, Theme.Space.xl)
                    }

                    PrimaryButton(title: applying ? "Guardando…" : "Usar estos datos", fillsWidth: true) { apply() }
                        .disabled(applying)
                        .padding(.top, Theme.Space.xl)
                }
                .screenContent()
            }
            .pushedScreen("Vista previa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BarButton("Cerrar la vista previa") { dismiss() }
                }
            }
        }
        .task {
            candidate = await model.library.details(for: candidate, bookID: bookID)
        }
        .task {
            let urls = await model.library.coverOptions(for: candidate, bookID: bookID)
            let current = book.flatMap { model.library.coverURL(for: $0) }
            coverOptions = (current.map { [.current($0)] } ?? []) + urls.map { .remote($0) }
            // Sin portada, la primera de internet; con portada, la tuya (salvo que sea muy probable).
            let keepsMine = current != nil && candidate.confidence < MetadataMatcher.autoApplyThreshold
            coverChoice = keepsMine ? coverOptions.first : (urls.first.map { .remote($0) } ?? coverOptions.first)
            loadingCovers = false
        }
        .errorAlert("No pude aplicar los datos", message: $errorMessage, back: "Volver a la vista previa")
    }

    /// El libro como quedaría (mismas reglas que al aplicar).
    private var preview: Book? {
        book.map { MetadataMatcher.replace($0, with: candidate) }
    }

    private func apply() {
        applying = true
        Task {
            do {
                let pick: LibraryStore.CoverPick
                switch coverChoice {
                case .remote(let url): pick = .url(url)
                case .current, nil: pick = .keep
                }
                try await model.library.apply(candidate, to: bookID, cover: pick)
                dismiss()
                onApplied()
            } catch {
                errorMessage = error.localizedDescription
            }
            applying = false
        }
    }
}

/// «Buscar con otros datos»: cuando el archivo trae un título o autor raro.
struct OtherSearchSheet: View {
    let book: Book
    let onSearch: (String, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var author: String
    @State private var isbn: String

    init(book: Book, onSearch: @escaping (String, String?, String?) -> Void) {
        self.book = book
        self.onSearch = onSearch
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.authors.first ?? "")
        _isbn = State(initialValue: book.identifiers["isbn"] ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $title)
                    TextField("Autor", text: $author)
                    TextField("ISBN (opcional)", text: $isbn)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                } footer: {
                    Text("Con el ISBN de la página legal del libro la búsqueda es exacta.")
                }
            }
            .formScreen()
            .sheetTitle("Buscar con otros datos")
            .sheetActions(leave: SheetAction(title: "Cerrar la búsqueda") { dismiss() },
                          confirm: SheetAction(title: "Buscar con estos datos",
                                               disabled: title.trimmingCharacters(in: .whitespaces).isEmpty && isbn.isEmpty) {
                let trimmed = { (text: String) in text.trimmingCharacters(in: .whitespaces) }
                onSearch(trimmed(title), trimmed(author).isEmpty ? nil : trimmed(author),
                         trimmed(isbn).isEmpty ? nil : trimmed(isbn))
                dismiss()
            })
        }
    }
}

/// Lo que se completó solo en un libro: dato por dato, con «Deshacer».
struct FilledScreen: View {
    let bookID: UUID
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    private var book: ShelfBook? { model.shelfBook(id: bookID.uuidString) }
    private var changes: [FilledChange] { model.library.filled[bookID]?.changes ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Datos nuevos")
                if let book {
                    BookRow(book: book, detail: book.author).padding(.top, Theme.Space.l)
                }
                if changes.isEmpty {
                    EmptyState(title: "Nada que revisar", message: "Ya no quedan datos nuevos en este libro.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(changes, id: \.field) { change in
                            CompareRow(label: change.field.label, new: change.field.display(change.new),
                                       old: change.field.display(change.old)) { undo(change.field) }
                        }
                    }
                    .padding(.top, Theme.Space.l)
                    VStack(spacing: Theme.Space.l) {
                        PrimaryButton(title: "Dejar estos datos", fillsWidth: true) {
                            model.library.forgetFilled(bookID)
                            dismiss()
                        }
                        SecondaryButton(title: "Deshacer todo", systemImage: "arrow.uturn.backward") {
                            do {
                                try model.library.undoAllFilled(for: bookID)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .padding(.top, Theme.Space.xl)
                }
            }
            .screenContent()
        }
        .pushedScreen()
        .errorAlert("No pude deshacer el cambio", message: $errorMessage, back: "Volver a la revisión")
    }

    private func undo(_ field: FilledField) {
        do {
            try model.library.undoFilled(field, for: bookID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
