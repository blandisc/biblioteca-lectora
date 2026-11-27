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
    @Environment(\.dismiss) private var dismiss

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
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        coverPreview
                            .frame(width: Theme.Size.coverEditor)
                        VStack(alignment: .leading, spacing: Theme.Space.l) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("Elegir de Fotos", systemImage: "photo")
                            }
                            Button {
                                choosingCoverFile = true
                            } label: {
                                Label("Elegir archivo", systemImage: "folder")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, Theme.Space.xs)
                } header: {
                    Text("Portada")
                }

                // Cada dato con su nombre arriba, también ya escrito: el campo del sistema solo
                // enseñaba la pista y, lleno, no decía qué era (UX-3a).
                Section(BookSection.book.rawValue) {
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
                }

                Section(BookSection.edition.rawValue) {
                    LabeledField(label: "Editorial", text: optional(\.publisher))
                    LabeledField(label: "Publicado", prompt: BookFields.publishedPrompt, text: optional(\.published))
                    LabeledField(label: "ISBN", text: $isbn)
                    LanguagePicker(code: Binding(
                        get: { draft.language ?? "" },
                        set: { draft.language = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section(BookSection.reading.rawValue) {
                    StatusPicker(status: Binding(get: { draft.readingStatus }, set: { draft.readingStatus = $0 ?? .toRead }))
                    HStack {
                        Text("Valoración")
                        Spacer()
                        RatingPicker(rating: $draft.rating)
                    }
                    LabeledField(label: "Etiquetas", prompt: "Sepáralas con comas", text: $tags)
                }

                Section(BookSection.summary.rawValue) {
                    TextEditor(text: optional(\.summary))
                        .frame(minHeight: Theme.Size.textEditor)
                }
            }
            .formScreen()
            .sheetTitle("Editar datos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dejar como está") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar cambios", action: save)
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (draft.series != nil && seriesInput.isInvalid))
                }
            }
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
        do {
            try model.library.update(edited, cover: newCover)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
