import ImageIO
import LectoraCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Edición manual de los datos de un libro: para cuando no se encontró nada o
/// se confundió de libro. Guarda en el catálogo y en el `metadata.opf` de Calibre.
struct MetadataEditorView: View {
    let book: Book
    @EnvironmentObject private var model: AppModel
    /// Cierra la hoja o, en un pliego, su panel (`SidePanel`).
    private let dismiss = SheetDismiss()

    @State private var draft: Book
    @State private var authors: String
    @State private var tags: String
    @State private var seriesIndex: String
    @State private var isbn: String
    @State private var newCover: Data?
    @State private var photo: PhotosPickerItem?
    @State private var choosingCoverFile = false
    @State private var saveError: String?

    init(book: Book) {
        self.book = book
        _draft = State(initialValue: book)
        _authors = State(initialValue: BookFields.authorsText(book.authors))
        _tags = State(initialValue: BookFields.tagsText(book.tags))
        _seriesIndex = State(initialValue: book.seriesIndex.flatMap(ShelfBook.number) ?? "")
        _isbn = State(initialValue: book.identifiers["isbn"] ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Con la letra más grande, los botones bajan bajo la portada («Elegi|r» se cortaba) y
                    // su nombre usa dos renglones, con el ícono dentro del texto (la fila de un formulario lo dejaba
                    // en uno, con «…»).
                    AdaptiveStack(rowAlignment: .top, spacing: Theme.Space.l) {
                        // Del alto de una portada, no más: apilada, se quedaba el alto que les tocaba a los botones.
                        coverPreview
                            .frame(width: Theme.Size.coverEditor)
                            .aspectRatio(Theme.Size.coverAspect, contentMode: .fit)
                        VStack(alignment: .leading, spacing: Theme.Space.l) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Text("\(Image(systemName: "photo"))  Elegir de Fotos").multilineTextAlignment(.leading)
                            }
                            Button {
                                choosingCoverFile = true
                            } label: {
                                Text("\(Image(systemName: "folder"))  Elegir archivo").multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.borderless)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, Theme.Space.xs)
                } header: {
                    CapsText(text: "Portada")
                }

                // Cada dato con su nombre arriba, también ya escrito: el campo del sistema solo
                // enseñaba la pista y, lleno, no decía qué era (UX-3a).
                Section {
                    LabeledField(label: "Título", text: $draft.title)
                    LabeledField(label: "Autores", prompt: "Sepáralos con &", text: $authors)
                    LabeledField(label: "Serie", text: Binding(
                        get: { draft.series ?? "" },
                        set: { draft.series = $0.isEmpty ? nil : $0 }
                    ))
                    if draft.series != nil {
                        LabeledField(label: "Número en la serie", text: $seriesIndex)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        if seriesInput.isInvalid {
                            Text(SeriesIndexInput.hint)
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                } header: {
                    CapsText(text: BookSection.book.rawValue)
                }

                Section {
                    LabeledField(label: "Editorial", text: optional(\.publisher))
                    LabeledField(label: "Publicado", prompt: BookFields.publishedPrompt, text: optional(\.published))
                    LabeledField(label: "ISBN", text: $isbn)
                    LanguagePicker(code: Binding(
                        get: { draft.language ?? "" },
                        set: { draft.language = $0.isEmpty ? nil : $0 }
                    ))
                } header: {
                    CapsText(text: BookSection.edition.rawValue)
                }

                Section {
                    StatusPicker(status: Binding(get: { draft.readingStatus }, set: { draft.readingStatus = $0 ?? .toRead }))
                    HStack {
                        Text("Valoración")
                        Spacer()
                        RatingPicker(rating: $draft.rating)
                    }
                    LabeledField(label: "Etiquetas", prompt: "Sepáralas con comas", text: $tags)
                } header: {
                    CapsText(text: BookSection.reading.rawValue)
                }

                Section {
                    TextEditor(text: optional(\.summary))
                        .frame(minHeight: Theme.Size.textEditor)
                } header: {
                    CapsText(text: BookSection.summary.rawValue)
                }
            }
            .formScreen()
            .sheetTitle("Editar datos")
            .sheetActions(leave: SheetAction(title: "Dejar como está") { dismiss() },
                          confirm: SheetAction(title: "Guardar cambios",
                                               disabled: draft.title.trimmingCharacters(in: .whitespaces).isEmpty
                                                   || (draft.series != nil && seriesInput.isInvalid),
                                               action: save))
            .onChange(of: photo) { _, item in
                Task { newCover = try? await item?.loadTransferable(type: Data.self) }
            }
            .fileImporter(isPresented: $choosingCoverFile, allowedContentTypes: [.image]) { result in
                guard let url = try? result.get() else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                newCover = try? Data(contentsOf: url)
            }
            .errorAlert("No pude guardar los datos", message: $saveError, back: "Volver a los datos")
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let newCover, let source = CGImageSourceCreateWithData(newCover as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            FittedCover(image: Image(decorative: image, scale: 1))
                .aspectRatio(Theme.Size.coverAspect, contentMode: .fit)
                .coverShape()
        } else {
            CoverView(title: draft.title, author: authors, style: .generated(for: draft.title),
                      image: model.library.coverURL(for: book))
        }
    }

    /// Campo de texto para un dato opcional del libro.
    private func optional(_ keyPath: WritableKeyPath<Book, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var seriesInput: SeriesIndexInput { SeriesIndexInput(seriesIndex) }

    private func save() {
        var edited = draft
        edited.authors = BookFields.authors(authors)
        edited.tags = BookFields.tags(tags)
        edited.seriesIndex = edited.series == nil ? nil : seriesInput.value(keeping: book.seriesIndex)
        edited.identifiers["isbn"] = BookFields.isbn(isbn)
        // El libro al abrir, pasado por los mismos campos: así un dato que no tocaste no cuenta
        // como cambio aunque el campo lo escriba distinto.
        var loaded = book
        loaded.authors = BookFields.authors(BookFields.authorsText(book.authors))
        loaded.tags = BookFields.tags(BookFields.tagsText(book.tags))
        loaded.seriesIndex = book.series == nil ? nil
            : SeriesIndexInput(book.seriesIndex.flatMap(ShelfBook.number) ?? "").value(keeping: book.seriesIndex)
        loaded.identifiers["isbn"] = BookFields.isbn(book.identifiers["isbn"] ?? "")
        // Solo lo que cambiaste aquí va encima del libro de ahora: lo que llegó mientras tanto
        // (de otro dispositivo o de internet) no se pisa (auditoría 1).
        let current = model.library.book(id: book.id) ?? book
        do {
            try model.library.update(Book.applyingEdits(from: edited, loaded: loaded, onto: current), cover: newCover)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
