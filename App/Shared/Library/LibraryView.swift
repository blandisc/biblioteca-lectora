import SwiftUI

/// Biblioteca (v7-Biblioteca): un botón para ordenar, un «+» y un control
/// Portadas/Lista. Nada más arriba.
struct LibraryView: View {
    enum Sort: String, CaseIterable, Identifiable {
        case recent = "Recientes"
        case title = "Título"
        case author = "Autor"
        case progress = "Avance"
        var id: Self { self }
    }

    enum Layout: String, CaseIterable, Identifiable {
        case covers = "Portadas"
        case list = "Lista"
        var id: Self { self }
    }

    @EnvironmentObject private var model: AppModel
    @AppStorage("library.sort") private var sort: Sort = .recent
    @AppStorage("library.layout") private var layout: Layout = .covers
    @AppStorage("library.onlyDownloaded") private var onlyDownloaded = false

    private var books: [ShelfBook] {
        Self.sorted(model.shelf.filter { !onlyDownloaded || !$0.inCloudOnly }, by: sort)
    }

    static func sorted(_ books: [ShelfBook], by sort: Sort) -> [ShelfBook] {
        switch sort {
        case .recent: books.sorted { $0.addedDaysAgo < $1.addedDaysAgo }
        case .title: books.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .author: books.sorted { $0.author.localizedStandardCompare($1.author) == .orderedAscending }
        case .progress: books.sorted { $0.progress > $1.progress }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.horizontal, 4)
                    Picker("Vista", selection: $layout) {
                        ForEach(Layout.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch layout {
                    case .covers: CoverGrid(books: books)
                    case .list: BookList(books: books)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
                .animation(.snappy, value: layout)
                .animation(.snappy, value: sort)
            }
            .background(Theme.groupedBackground.ignoresSafeArea())
            .navigationTitle("Biblioteca")
            .navigationDestination(for: ShelfBook.self) { BookDetailView(book: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Picker("Ordenar por", selection: $sort) {
                            ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Divider()
                        Toggle("Solo descargados", isOn: $onlyDownloaded)
                    } label: {
                        Label("Ordenar", systemImage: "arrow.up.arrow.down")
                    }
                    Button { model.importing = true } label: {
                        Label("Añadir libro", systemImage: "plus")
                    }
                }
            }
        }
    }

    private var summary: String {
        let all = model.shelf
        let here = all.filter { !$0.inCloudOnly }.count
        return "\(all.count) libros · \(here) en este dispositivo"
    }
}

private struct CoverGrid: View {
    let books: [ShelfBook]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    VStack(alignment: .leading, spacing: 6) {
                        ShelfCover(book: book)
                        Text(book.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(book.caption)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PressableStyle())
                .contextMenu { BookMenu(book: book) }
            }
        }
    }
}

private struct BookList: View {
    let books: [ShelfBook]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    HStack(spacing: 14) {
                        ShelfCover(book: book)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(book.caption)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if book.inCloudOnly {
                            Image(systemName: "icloud")
                                .foregroundStyle(Theme.secondaryInk)
                                .accessibilityLabel("En iCloud")
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { BookMenu(book: book) }
                if book.id != books.last?.id {
                    Divider().padding(.leading, 74)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// Menú contextual de un libro (v7-MenuLibro).
private struct BookMenu: View {
    let book: ShelfBook
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if book.file != nil {
            Button { model.open(book) } label: { Label("Leer", systemImage: "book") }
        } else {
            Button {} label: { Label("Descargar", systemImage: "icloud.and.arrow.down") }
        }
        Button {} label: { Label("Añadir a la mesa", systemImage: "tray.and.arrow.down") }
        Button {} label: { Label("Editar metadatos", systemImage: "pencil") }
        Divider()
        Button {} label: { Label("Marcar como leído", systemImage: "checkmark.circle") }
    }
}
