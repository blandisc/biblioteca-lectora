import SwiftUI

/// Estilo Editorial (v5): papel, tipografía y una barra de texto con un punto rojo.
/// La búsqueda vive dentro de la biblioteca.
struct EditorialRootView: View {
    enum Place: String, CaseIterable, Identifiable {
        case desk = "Mesa"
        case library = "Biblioteca"
        case notebook = "Cuaderno"
        var id: Self { self }
    }

    @State private var section: Place = {
        switch LaunchOptions.tab {
        case "library": .library
        case "notebook": .notebook
        default: .desk
        }
    }()

    var body: some View {
        Group {
            switch section {
            case .desk: EditorialHomeView()
            case .library: EditorialLibraryView()
            case .notebook: EditorialNotebookView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorialTabBar(selection: $section)
        }
    }
}

private struct EditorialTabBar: View {
    @Binding var selection: EditorialRootView.Place

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorialRootView.Place.allCases) { item in
                let selected = item == selection
                Button { selection = item } label: {
                    VStack(spacing: 5) {
                        Text(item.rawValue)
                            .font(.footnote.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                        Circle()
                            .fill(selected ? Theme.pencil : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .background(Theme.Editorial.paper.ignoresSafeArea(edges: .bottom))
    }
}

/// Encabezado de pantalla: serif grande dentro del contenido, sin barra de navegación.
struct EditorialHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.serifTitle(30, weight: .medium))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
                .font(.title3)
                .foregroundStyle(Theme.secondaryInk)
                .buttonStyle(.plain)
        }
    }
}

extension View {
    /// Pantalla raíz del estilo Editorial: papel de fondo y sin barra de navegación.
    func editorialScreen() -> some View {
        self
            .background(Theme.Editorial.paper.ignoresSafeArea())
            .navigationDestination(for: ShelfBook.self) { BookDetailView(book: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
    }
}

// MARK: - Mesa

struct EditorialHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAccount = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                let book = model.currentBook
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Button(action: model.continueReading) {
                            ShelfCover(book: book).frame(width: 132)
                        }
                        .buttonStyle(PressableStyle())
                        Spacer()
                        Button { showsAccount = true } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cuenta y apariencia")
                    }

                    Text(book.title)
                        .font(.serifTitle(28, weight: .medium))
                        .padding(.top, 28)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, 4)

                    ThinProgress(value: book.progress, height: 2)
                        .padding(.top, 24)
                    HStack {
                        Text("\(Int(book.progress * 100)) % leído")
                        Spacer()
                        Text(book.note ?? "")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, 8)

                    Button(action: model.continueReading) {
                        Text("Seguir leyendo")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.onInk)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 46)
                            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Editorial.buttonRadius, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 24)

                    if !model.desk.isEmpty {
                        Text("En la mesa")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 52)
                            .padding(.bottom, 14)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                            ForEach(model.desk.prefix(6)) { item in
                                NavigationLink(value: item) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ShelfCover(book: item)
                                        Text(item.caption)
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryInk)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .editorialScreen()
            .sheet(isPresented: $showsAccount) { AccountView() }
        }
    }
}

// MARK: - Biblioteca

struct EditorialLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("library.sort") private var sort: LibraryView.Sort = .recent
    @AppStorage("library.onlyDownloaded") private var onlyDownloaded = false
    @State private var query = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)

    private var books: [ShelfBook] {
        let term = query.trimmingCharacters(in: .whitespaces)
        let visible = model.shelf.filter { book in
            (!onlyDownloaded || !book.inCloudOnly)
                && (term.isEmpty || book.title.localizedStandardContains(term) || book.author.localizedStandardContains(term))
        }
        return LibraryView.sorted(visible, by: sort)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EditorialHeading(title: "Biblioteca") {
                        Button { model.importing = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Añadir libro")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryInk)
                        TextField("Buscar en \(model.shelf.count) libros", text: $query)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(Theme.Editorial.field, in: RoundedRectangle(cornerRadius: Theme.Editorial.buttonRadius, style: .continuous))
                    .padding(.top, 18)

                    HStack {
                        Menu {
                            Picker("Ordenar por", selection: $sort) {
                                ForEach(LibraryView.Sort.allCases) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Text(sort.rawValue)
                        }
                        Spacer()
                        Menu {
                            Picker("Mostrar", selection: $onlyDownloaded) {
                                Text("Todos").tag(false)
                                Text("Solo descargados").tag(true)
                            }
                        } label: {
                            Text(onlyDownloaded ? "Solo descargados" : "Todos")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .padding(.top, 14)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ShelfCover(book: book)
                                    Text(book.title)
                                        .font(.caption)
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.top, 18)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
            .editorialScreen()
        }
    }
}

// MARK: - Cuaderno

struct EditorialNotebookView: View {
    @State private var part: NotebookView.Part = .review

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EditorialHeading(title: "Cuaderno") { EmptyView() }

                    HStack(spacing: 22) {
                        ForEach(NotebookView.Part.allCases) { item in
                            let selected = item == part
                            Button { part = item } label: {
                                Text(item.rawValue)
                                    .font(.subheadline.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                                    .padding(.vertical, 10)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(selected ? Theme.ink : .clear).frame(height: 1.5)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.track).frame(height: 1) }
                    .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 24) {
                        switch part {
                        case .review:
                            ForEach(sampleHighlights) { highlight in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(highlight.book)
                                        .font(.caption)
                                        .foregroundStyle(Theme.tertiaryInk)
                                    Text(highlight.text)
                                        .font(.system(size: 17, design: .serif))
                                        .lineSpacing(4)
                                    if let note = highlight.note {
                                        Text(note)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.pencil)
                                    }
                                }
                            }
                        case .books:
                            ForEach(SampleLibrary.books.filter { $0.progress > 0 }) { book in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title).font(.system(size: 17, design: .serif))
                                        Text(book.author).font(.footnote).foregroundStyle(Theme.secondaryInk)
                                    }
                                    Spacer()
                                    Text("\(sampleHighlightCount(book))")
                                        .font(.footnote)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.pencil)
                                }
                            }
                        case .topics:
                            ForEach(Array(sampleTopics.enumerated()), id: \.offset) { _, topic in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(topic.0).font(.system(size: 17, design: .serif))
                                    Spacer()
                                    Text("\(topic.1)").font(.footnote).monospacedDigit().foregroundStyle(Theme.secondaryInk)
                                }
                            }
                        }
                    }
                    .padding(.top, 22)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .editorialScreen()
        }
    }
}
