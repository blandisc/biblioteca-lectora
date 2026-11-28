import LectoraCore
import SwiftUI

/// Cuaderno: tus notas (Markdown en Gabinete/Notas) y tus subrayados.
struct NotebookScreen: View {
    enum Part: String, CaseIterable, Identifiable {
        case notes = "Notas"
        case highlights = "Subrayados"
        var id: Self { self }
    }

    /// Orden de los subrayados.
    enum HighlightOrder: String, CaseIterable, Identifiable {
        case recent = "Recientes"
        case books = "Por libro"
        var id: Self { self }
    }

    @EnvironmentObject private var model: AppModel
    @State private var part: Part = LaunchOptions.screen == "highlights" ? .highlights : .notes
    @State private var order: HighlightOrder = .recent
    /// Capturas automáticas: `-screenshot.screen settings` abre Ajustes.
    @State private var showsAccount = LaunchOptions.screen == "settings"
    @State private var path = NavigationPath()
    /// Subrayado que se lleva a una nota (toque largo en el Cuaderno).
    @State private var toNote: Annotation?

    private var highlights: [Annotation] { model.annotations.allAnnotations() }
    private var notes: [Note] { model.notes.notes }

    private func shelfBook(_ id: UUID) -> ShelfBook? {
        model.shelfBook(id: id.uuidString)
    }

    var body: some View {
        // Con el Duo abierto y acostado, la lista a la izquierda y la nota abierta a la derecha.
        FoldSplit(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Cuaderno") {
                        #if os(iOS)
                        // En la Mac, Ajustes vive en Gabinete › Ajustes… (⌘,): sin engrane en el contenido.
                        IconButton(systemImage: "gearshape", label: "Ajustes: conexiones, carpeta y apariencia") { showsAccount = true }
                        #endif
                        // El acento verde de la pantalla, siempre al final: escribir una nota.
                        AccentIconButton(systemImage: "plus", label: "Nota nueva") { path.append(NoteRef.new()) }
                    }
                    FilterBar(items: Part.allCases, selection: $part) { $0.rawValue }
                        .padding(.top, Theme.Space.s)

                    summary

                    Group {
                        switch part {
                        case .notes: notesList
                        case .highlights:
                            switch order {
                            case .recent: recent
                            case .books: byBook
                            }
                        }
                    }
                    .padding(.top, part == .notes ? Theme.Space.xs : Theme.Space.l)
                }
                .screenContent()
            }
            .screen()
            #if os(iOS)
            .sidePanel(isPresented: $showsAccount) { SettingsScreen() }
            #endif
            .sheet(item: $toNote) { highlight in
                NoteLinkSheet(annotation: highlight, bookTitle: shelfBook(highlight.bookID)?.title ?? highlight.bookTitle ?? MetadataCleaner.untitled)
                    .duoBars()
            }
            .onAppear(perform: openForScreenshots)
        } placeholder: {
            FoldPlaceholder(title: "Elige una nota",
                            message: "Toca una nota o un subrayado a la izquierda y aquí lo lees o lo escribes, con tu lista a la vista.")
        }
    }

    /// «4 notas» o el orden de los subrayados. Dónde viven las notas lo dice Ajustes › Tu Gabinete:
    /// «4 NOTAS · EN NOTAS» se leía raro.
    @ViewBuilder
    private var summary: some View {
        // Sin nada que contar no digo «0 notas» junto a «Sin notas todavía» (auditoría 8).
        switch part {
        case .notes where notes.isEmpty, .highlights where highlights.isEmpty:
            EmptyView()
        case .notes:
            CountLine(text: notes.count.counted("nota", "notas"))
        case .highlights:
            CountLine(text: highlights.count.counted("subrayado", "subrayados")) {
                SortMenu(options: HighlightOrder.allCases, selection: $order) { $0.rawValue }
            }
        }
    }

    @ViewBuilder
    private var notesList: some View {
        if notes.isEmpty {
            EmptyState(title: "Sin notas todavía",
                       message: "Escribe ideas, resúmenes o lo que te dejó un libro. Para enlazar un libro, abre dos corchetes y elige su título de tu biblioteca; desde el lector llevas tus subrayados a una nota. Cada nota es un archivo de texto en la carpeta Notas de tu Gabinete, que abre también Obsidian.",
                       actionTitle: "Nota nueva", systemImage: "plus") { path.append(NoteRef.new()) }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(notes) { note in
                    NavigationLink(value: NoteRef(fileName: note.fileName)) { NoteRow(note: note, isInLibrary: { model.shelfBook(titled: $0) != nil }) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    /// Capturas automáticas: `-screenshot.screen note` abre la primera nota (`noteEdit`, ya escribiendo).
    private func openForScreenshots() {
        if LaunchOptions.screen == "note" || LaunchOptions.screen == "noteEdit", path.isEmpty, let first = notes.first {
            path.append(NoteRef(fileName: first.fileName, writes: LaunchOptions.screen == "noteEdit"))
        }
    }

    @ViewBuilder
    private var recent: some View {
        if highlights.isEmpty {
            EmptyState(title: "Sin subrayados todavía",
                       message: "Mantén el dedo sobre el texto mientras lees y elige «Subrayar». Lo que marques aparece aquí.")
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                ForEach(highlights) { highlight in
                    QuoteBlock(label: shelfBook(highlight.bookID)?.title ?? highlight.bookTitle, text: highlight.quote, note: highlight.note)
                        .contextMenu {
                            Button { toNote = highlight } label: { Label(SelectionAction.toNote.title, systemImage: SelectionAction.toNote.symbol) }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var byBook: some View {
        let grouped = Dictionary(grouping: highlights, by: \.bookID)
        let groups = grouped
            .compactMap { id, items in shelfBook(id).map { BookCount(book: $0, count: items.count) } }
            .sorted { $0.book.title.localizedStandardCompare($1.book.title) == .orderedAscending }
        // Lo que llegó de Readwise de libros que no están en tu biblioteca.
        let outside = grouped.filter { shelfBook($0.key) == nil }
            .map { OutsideBook(id: $0.key, title: $0.value.first?.bookTitle ?? MetadataCleaner.untitled,
                               author: $0.value.first?.bookAuthor, highlights: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if groups.isEmpty && outside.isEmpty {
            EmptyState(title: "Sin libros subrayados", message: "Aquí verás cada libro con el número de subrayados que tiene.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    NavigationLink(value: group.book) {
                        BookRow(book: group.book, detail: group.book.author) {
                            Text("\(group.count)").monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if !outside.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    SectionHeader("Fuera de tu biblioteca")
                    Text("Subrayados que llegaron de Readwise (Kindle, Apple Books…) de libros que no tienes en Gabinete.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                    ForEach(outside) { book in
                        VStack(alignment: .leading, spacing: Theme.Space.l) {
                            TitleDetailRow(title: book.title, detail: book.author)
                            ForEach(book.highlights) { QuoteBlock(text: $0.quote, note: $0.note) }
                        }
                    }
                }
                .padding(.top, Theme.Space.xxl)
            }
        }
    }
}

/// Un libro que solo existe en Readwise, con sus subrayados.
private struct OutsideBook: Identifiable {
    let id: UUID
    let title: String
    let author: String?
    let highlights: [Annotation]
}

private struct BookCount: Identifiable {
    let book: ShelfBook
    let count: Int
    var id: String { book.id }
}
