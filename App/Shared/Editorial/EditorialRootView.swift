import SwiftUI

/// Estilo Editorial (elegido): papel y tipografía, con la barra de pestañas
/// nativa de iOS y la búsqueda aparte en el dock.
struct EditorialRootView: View {
    enum Place: String, Hashable {
        case desk, library, notebook, search
    }

    @EnvironmentObject private var model: AppModel
    @State private var section: Place = {
        switch LaunchOptions.tab {
        case "library": .library
        case "notebook": .notebook
        case "search": .search
        default: .desk
        }
    }()

    var body: some View {
        tabs.modifier(MiniPlayerAccessory(book: model.listening))
    }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            TabView(selection: $section) {
                Tab("Mesa", systemImage: "book", value: Place.desk) { EditorialHomeView() }
                Tab("Biblioteca", systemImage: "books.vertical", value: Place.library) { EditorialLibraryView() }
                Tab("Cuaderno", systemImage: "note.text", value: Place.notebook) { EditorialNotebookView() }
                Tab(value: Place.search, role: .search) { SearchView() }
            }
        } else {
            TabView(selection: $section) {
                EditorialHomeView()
                    .tabItem { Label("Mesa", systemImage: "book") }
                    .tag(Place.desk)
                EditorialLibraryView()
                    .tabItem { Label("Biblioteca", systemImage: "books.vertical") }
                    .tag(Place.library)
                EditorialNotebookView()
                    .tabItem { Label("Cuaderno", systemImage: "note.text") }
                    .tag(Place.notebook)
                SearchView()
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(Place.search)
            }
        }
    }
}

/// El mini reproductor vive sobre la barra de pestañas (iOS 26). En versiones
/// anteriores no se muestra; el audio sigue en la pantalla de bloqueo.
private struct MiniPlayerAccessory: ViewModifier {
    let book: ShelfBook?

    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.2)
        if #available(iOS 26.0, *), let book {
            content.tabViewBottomAccessory { MiniPlayer(book: book) }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Portada, título, capítulo con barritas que se mueven mientras suena, pausa
/// dentro de un anillo de avance y +30 s. Solo interfaz por ahora.
struct MiniPlayer: View {
    let book: ShelfBook
    @State private var playing = true
    private let chapterProgress = 0.38

    var body: some View {
        HStack(spacing: 12) {
            CoverView(title: book.title, author: book.author, style: book.cover)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(book.title)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if playing { EqualizerBars() }
                    Text("Cap. VII · quedan 18 min")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
            Button { playing.toggle() } label: {
                ZStack {
                    Circle().stroke(Theme.track, lineWidth: 2.5)
                    Circle().trim(from: 0, to: chapterProgress)
                        .stroke(Theme.pencil, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 38, height: 38)
                .contentShape(Circle())
            }
            .accessibilityLabel(playing ? "Pausa" : "Reproducir")
            Button {} label: {
                Image(systemName: "goforward.30").font(.system(size: 20, weight: .medium))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("Adelantar 30 segundos")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
    }
}

private struct EqualizerBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach([0.5, 1.0, 0.7], id: \.self) { height in
                Capsule()
                    .fill(Theme.pencil)
                    .frame(width: 2, height: 10 * height)
                    .phaseAnimator([1.0, 0.4]) { bar, phase in
                        bar.scaleEffect(y: phase, anchor: .bottom)
                    } animation: { _ in .easeInOut(duration: 0.45 + height * 0.2) }
            }
        }
        .frame(height: 10, alignment: .bottom)
        .accessibilityHidden(true)
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
    @Environment(\.bookOpeningNamespace) private var opening
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                let book = model.currentBook
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: model.continueReading) {
                        ShelfCover(book: book).frame(width: 132)
                    }
                    .buttonStyle(PressableStyle())
                    .bookOpeningSource(in: opening)

                    Text(book.title)
                        .font(.serifTitle(28, weight: .medium))
                        .padding(.top, 28)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, 4)

                    if let sentence = book.lastSentence {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Donde lo dejaste")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                            Text("«\(sentence)»")
                                .font(.system(size: 17, design: .serif).italic())
                                .lineSpacing(3)
                        }
                        .padding(.leading, 14)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.pencil).frame(width: 2)
                        }
                        .padding(.top, 18)
                    }

                    ThinProgress(value: book.progress, height: 2)
                        .padding(.top, 22)
                    HStack {
                        Text("\(Int(book.progress * 100)) % leído")
                        Spacer()
                        Text(book.note ?? "")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, 8)

                    HStack(spacing: 10) {
                        Button(action: model.continueReading) {
                            Text("Seguir leyendo")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.onInk)
                                .padding(.horizontal, 20)
                                .frame(minHeight: 46)
                                .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Editorial.buttonRadius, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())

                        Button {
                            withAnimation(.snappy) { model.listening = model.listening == nil ? book : nil }
                        } label: {
                            Image(systemName: "headphones")
                                .font(.title3)
                                .foregroundStyle(Theme.ink)
                                .frame(width: 46, height: 46)
                                .background(Theme.Editorial.field, in: Circle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Escuchar como audiolibro")
                    }
                    .padding(.top, 24)

                    if !model.desk.isEmpty {
                        Text("En la mesa")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 34)
                            .padding(.bottom, 14)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                            ForEach(model.desk.prefix(3)) { item in
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .editorialScreen()
        }
    }
}

// MARK: - Biblioteca

struct EditorialLibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case reading = "En curso"
        case unread = "Sin empezar"
        case series = "Series"
        case cloud = "Sin descargar"
        var id: Self { self }

        func includes(_ book: ShelfBook) -> Bool {
            switch self {
            case .all: true
            case .reading: book.isReading
            case .unread: book.progress == 0
            case .series: (book.seriesCount ?? 0) > 1
            case .cloud: book.inCloudOnly
            }
        }
    }

    @EnvironmentObject private var model: AppModel
    @AppStorage("library.sort") private var sort: LibraryView.Sort = .recent
    @AppStorage("library.layout") private var layout: LibraryView.Layout = .covers
    @State private var filter: Filter = .all
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)

    private var books: [ShelfBook] {
        LibraryView.sorted(model.shelf.filter(filter.includes), by: sort)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        EditorialHeading(title: "Biblioteca") {
                            HStack(spacing: 18) {
                                Button {
                                    withAnimation(.snappy) { layout = layout == .covers ? .list : .covers }
                                } label: {
                                    Image(systemName: layout == .covers ? "list.bullet" : "square.grid.2x2")
                                }
                                .accessibilityLabel(layout == .covers ? "Ver como lista" : "Ver portadas")
                                Button { model.importing = true } label: { Image(systemName: "plus") }
                                    .accessibilityLabel("Añadir libro")
                            }
                            .foregroundStyle(Theme.ink)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Filter.allCases) { item in
                                    let selected = item == filter
                                    Button { withAnimation(.snappy) { filter = item } } label: {
                                        Text(item.rawValue)
                                            .font(.subheadline.weight(selected ? .semibold : .regular))
                                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(selected ? Theme.Editorial.field : .clear,
                                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.horizontal, -28)
                        .padding(.top, 12)

                        HStack {
                            Text(summary)
                            Spacer()
                            Menu {
                                Picker("Ordenar por", selection: $sort) {
                                    ForEach(LibraryView.Sort.allCases) { Text($0.rawValue).tag($0) }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(sort.rawValue)
                                    Image(systemName: "arrow.up.arrow.down").font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(Theme.ink)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ordenar: \(sort.rawValue)")
                        }
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, 14)

                        switch layout {
                        case .covers: grid.padding(.top, 18)
                        case .list: list.padding(.top, 8)
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .overlay(alignment: .trailing) {
                    if layout == .list {
                        LetterIndex { letter in
                            if let target = books.first(where: { $0.title.firstLetter == letter }) {
                                withAnimation { scroller.scrollTo(target.id, anchor: .top) }
                            }
                        }
                    }
                }
            }
            .editorialScreen()
        }
    }

    private var summary: String {
        let all = model.shelf
        return "\(all.count) libros · \(all.filter { !$0.inCloudOnly }.count) en este iPhone"
    }

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let count = book.seriesCount, count > 1 {
                            SeriesStack(book: book)
                        } else {
                            ShelfCover(book: book)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(book.title)
                                .font(.caption)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if let count = book.seriesCount, count > 1 {
                                Text("Serie · \(count)")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    HStack(spacing: 14) {
                        CoverView(title: book.title, author: book.author, style: book.cover)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(size: 17, design: .serif))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(book.caption)
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryInk)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if book.inCloudOnly {
                            Image(systemName: "icloud")
                                .foregroundStyle(Theme.secondaryInk)
                                .accessibilityLabel("En iCloud")
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.trailing, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.track).frame(height: 0.5) }
                .id(book.id)
            }
        }
    }
}

/// Las series se ven como una pila de portadas.
private struct SeriesStack: View {
    let book: ShelfBook

    var body: some View {
        ShelfCover(book: book)
            .background {
                ZStack {
                    CoverView(title: "", author: "", style: book.cover).brightness(-0.1).offset(x: 8, y: -8)
                    CoverView(title: "", author: "", style: book.cover).brightness(-0.05).offset(x: 4, y: -4)
                }
                .accessibilityHidden(true)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
    }
}

/// Índice A–Z al costado de la lista para brincar con el dedo.
private struct LetterIndex: View {
    let onSelect: (String) -> Void
    private let letters = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".map(String.init)

    var body: some View {
        VStack(spacing: 1) {
            ForEach(letters, id: \.self) { letter in
                Button(letter) { onSelect(letter) }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.pencil)
                    .frame(width: 18)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Índice alfabético")
    }
}

private extension String {
    /// Primera letra sin acentos, en mayúscula; la Ñ se respeta.
    var firstLetter: String {
        guard let first = first else { return "" }
        let letter = String(first).uppercased()
        return letter == "Ñ" ? letter : letter.folding(options: .diacriticInsensitive, locale: nil)
    }
}

// MARK: - Cuaderno

struct EditorialNotebookView: View {
    @State private var part: NotebookView.Part = .review
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EditorialHeading(title: "Cuaderno") {
                        Button { showsAccount = true } label: { Image(systemName: "person.crop.circle") }
                            .accessibilityLabel("Cuenta, conexiones y apariencia")
                    }

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
            .sheet(isPresented: $showsAccount) { AccountView() }
        }
    }
}
