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
    @State private var showsAccount = false
    @State private var path = NavigationPath()
    /// Subrayado que se lleva a una nota (toque largo en el Cuaderno).
    @State private var toNote: Annotation?

    private var highlights: [Annotation] { model.annotations.allAnnotations() }
    private var notes: [Note] { model.notes.notes }

    private func shelfBook(_ id: UUID) -> ShelfBook? {
        model.shelfBook(id: id.uuidString)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeading(title: "Cuaderno") {
                        // El acento verde de la pantalla: escribir una nota.
                        AccentIconButton(systemImage: "plus", label: "Nota nueva") { path.append(NoteRef.new()) }
                        Button { showsAccount = true } label: { Image(systemName: "person.crop.circle") }
                            .accessibilityLabel("Cuenta, conexiones y apariencia")
                    }
                    FilterBar(items: Part.allCases, selection: $part) { $0.rawValue }
                        .padding(.top, Theme.Space.m)

                    summary
                        .padding(.top, Theme.Space.m)

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
            .sheet(isPresented: $showsAccount) { SettingsScreen() }
            .sheet(item: $toNote) { highlight in
                NoteLinkSheet(annotation: highlight, bookTitle: shelfBook(highlight.bookID)?.title ?? "Sin título")
            }
            .onAppear(perform: openForScreenshots)
        }
    }

    /// «4 notas · en Gabinete/Notas» o el orden de los subrayados.
    @ViewBuilder
    private var summary: some View {
        HStack {
            switch part {
            case .notes:
                Text(notes.count == 1 ? "1 nota" : "\(notes.count) notas")
                    + Text(" · en \(CabinetLocation.notesFolder)")
            case .highlights:
                Text(highlights.count == 1 ? "1 subrayado" : "\(highlights.count) subrayados")
                Spacer()
                Menu {
                    Picker("Ordenar por", selection: $order) {
                        ForEach(HighlightOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label(order.rawValue, systemImage: "arrow.up.arrow.down")
                        .labelStyle(TrailingIconLabelStyle())
                        .foregroundStyle(Theme.ink)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("Ordenar: \(order.rawValue)")
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
    }

    @ViewBuilder
    private var notesList: some View {
        if notes.isEmpty {
            EmptyState(title: "Sin notas todavía",
                       message: "Escribe ideas, resúmenes o lo que te dejó un libro. Enlaza libros con [[ y lleva tus subrayados a una nota desde el lector. Cada nota es un archivo Markdown en Gabinete/Notas.",
                       actionTitle: "Nota nueva") { path.append(NoteRef.new()) }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(notes) { note in
                    NavigationLink(value: NoteRef(fileName: note.fileName)) { NoteRow(note: note) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    /// Capturas automáticas: `-screenshot.screen note` abre la primera nota.
    private func openForScreenshots() {
        if LaunchOptions.screen == "note", path.isEmpty, let first = notes.first {
            path.append(NoteRef(fileName: first.fileName))
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
                    QuoteBlock(label: shelfBook(highlight.bookID)?.title, text: highlight.quote, note: highlight.note)
                        .contextMenu {
                            Button { toNote = highlight } label: { Label("Llevar a una nota", systemImage: "note.text.badge.plus") }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var byBook: some View {
        let groups = Dictionary(grouping: highlights, by: \.bookID)
            .compactMap { id, items in shelfBook(id).map { BookCount(book: $0, count: items.count) } }
            .sorted { $0.book.title.localizedStandardCompare($1.book.title) == .orderedAscending }
        if groups.isEmpty {
            EmptyState(title: "Sin libros subrayados", message: "Aquí verás cada libro con el número de subrayados que tiene.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    NavigationLink(value: group.book) {
                        BookRow(book: group.book, detail: group.book.author) {
                            Text("\(group.count)").monospacedDigit().foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BookCount: Identifiable {
    let book: ShelfBook
    let count: Int
    var id: String { book.id }
}
