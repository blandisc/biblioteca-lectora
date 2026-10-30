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

/// «Por revisar»: los libros cuyos datos de internet no fueron seguros.
struct ReviewScreen: View {
    @EnvironmentObject private var model: AppModel

    private var pending: [ShelfBook] {
        model.library.reviews.keys
            .compactMap { model.shelfBook(id: $0.uuidString) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Por revisar")
                Text("Encontré estos libros en internet, pero no estoy seguro de que sean los tuyos. Elige los datos correctos o conserva los que tienen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, Theme.Space.xs)
                if !model.library.pendingLookup.isEmpty {
                    waiting.padding(.top, Theme.Space.l)
                }
                if pending.isEmpty && filled.isEmpty {
                    EmptyState(title: "Todo en orden", message: "No hay libros pendientes de revisar.")
                } else if !pending.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(pending) { book in
                            if let id = book.bookID {
                                NavigationLink(value: CandidatesRef(bookID: id)) {
                                    BookRow(book: book, detail: detail(for: id)) {
                                        Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, Theme.Space.l)
                }
                if !filled.isEmpty { filledSection }
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var filled: [ShelfBook] {
        model.library.filled
            .sorted { $0.value.date > $1.value.date }
            .compactMap { model.shelfBook(id: $0.key.uuidString) }
    }

    /// Lo que se completó solo: para revisarlo de un vistazo y deshacer lo que no quieras.
    private var filledSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Se completaron solos").font(.rowTitle)
                Spacer()
                Button("Todo bien") { model.library.forgetAllFilled() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.pencil)
                    .buttonStyle(.plain)
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
            LinkRow(title: count == 1 ? "1 libro espera conexión" : "\(count) libros esperan conexión",
                    value: model.library.identifying.isEmpty ? "Buscar ahora" : "Buscando…")
        }
        .buttonStyle(.plain)
        .disabled(!model.library.identifying.isEmpty)
    }

    private func detail(for id: UUID) -> String {
        guard let candidates = model.library.reviews[id], let best = candidates.first else {
            return "No lo encontré en internet"
        }
        let count = candidates.count == 1 ? "1 opción" : "\(candidates.count) opciones"
        return "\(count) · \(best.verdict)"
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
                        HStack(spacing: Theme.Space.m) {
                            ProgressView()
                            Text("Buscando en internet…")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(.vertical, Theme.Space.xl)
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

                VStack(spacing: Theme.Space.m) {
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
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if searchesFirst { await research() }
        }
        .sheet(item: $previewing) { candidate in
            CandidatePreview(bookID: bookID, candidate: candidate) { dismiss() }
        }
        .sheet(isPresented: $searchingOther) {
            if let record = model.library.book(id: bookID) {
                OtherSearchSheet(book: record) { title, author, isbn in
                    Task {
                        let decision = await model.library.search(title: title, author: author, isbn: isbn, for: bookID)
                        unreachable = decision == .unreachable
                    }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let record = model.library.book(id: bookID) { MetadataEditorView(book: record) }
        }
    }

    private func research() async {
        let decision = await model.library.identify(bookID, askAlways: true)
        unreachable = decision == .unreachable
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
                            Text(candidate.title).font(.rowTitle).foregroundStyle(Theme.ink)
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
                        ProgressView().padding(.vertical, Theme.Space.m)
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
                        CompareRow(label: "Idioma", new: preview.language.map(MetadataCandidate.languageName),
                                   old: book?.language.map(MetadataCandidate.languageName))
                        CompareRow(label: "ISBN", new: preview.identifiers["isbn"], old: book?.identifiers["isbn"])
                        CompareRow(label: "Serie", new: preview.series.map { name in
                            preview.seriesIndex.map { "\(name) · \(ShelfBook.number($0))" } ?? name
                        }, old: book?.series)
                        CompareRow(label: "Géneros", new: preview.tags.joined(separator: ", "), old: book?.tags.joined(separator: ", "))
                    }

                    if let summary = candidate.summary {
                        QuoteBlock(label: "Sinopsis", text: summary)
                            .padding(.top, Theme.Space.xl)
                    } else if candidate.workKey != nil {
                        ProgressView().padding(.top, Theme.Space.xl)
                    }

                    PrimaryButton(title: applying ? "Guardando…" : "Usar estos datos", fillsWidth: true) { apply() }
                        .disabled(applying)
                        .padding(.top, Theme.Space.xl)
                }
                .screenContent()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Vista previa")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
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
        .alert("No se pudo aplicar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
            .navigationTitle("Buscar con otros datos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buscar") {
                        let trimmed = { (text: String) in text.trimmingCharacters(in: .whitespaces) }
                        onSearch(trimmed(title), trimmed(author).isEmpty ? nil : trimmed(author),
                                 trimmed(isbn).isEmpty ? nil : trimmed(isbn))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && isbn.isEmpty)
                }
            }
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
                    VStack(spacing: Theme.Space.m) {
                        PrimaryButton(title: "Está bien", fillsWidth: true) {
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
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("No se pudo deshacer", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func undo(_ field: FilledField) {
        do {
            try model.library.undoFilled(field, for: bookID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
