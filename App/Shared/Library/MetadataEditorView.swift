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
        _authors = State(initialValue: book.authors.joined(separator: " & "))
        _tags = State(initialValue: book.tags.joined(separator: ", "))
        _seriesIndex = State(initialValue: book.seriesIndex.map(ShelfBook.number) ?? "")
        _isbn = State(initialValue: book.identifiers["isbn"] ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 16) {
                        coverPreview
                            .frame(width: 84)
                        VStack(alignment: .leading, spacing: 10) {
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
                    .padding(.vertical, 4)
                } header: {
                    Text("Portada")
                }

                Section("Libro") {
                    TextField("Título", text: $draft.title)
                    TextField("Autores (sepáralos con &)", text: $authors)
                    TextField("Serie", text: Binding(
                        get: { draft.series ?? "" },
                        set: { draft.series = $0.isEmpty ? nil : $0 }
                    ))
                    if draft.series != nil {
                        TextField("Número en la serie", text: $seriesIndex)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                Section("Publicación") {
                    TextField("Editorial", text: optional(\.publisher))
                    TextField("Año o fecha (AAAA-MM-DD)", text: optional(\.published))
                    TextField("ISBN", text: $isbn)
                    Picker("Idioma", selection: Binding(
                        get: { draft.language ?? "" },
                        set: { draft.language = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Sin indicar").tag("")
                        Text("Español").tag("es")
                        Text("Inglés").tag("en")
                        if let other = draft.language, !["es", "en"].contains(other) {
                            Text(Locale(identifier: "es").localizedString(forLanguageCode: other)?.capitalized ?? other).tag(other)
                        }
                    }
                }

                Section("Tu biblioteca") {
                    TextField("Etiquetas (sepáralas con comas)", text: $tags)
                    Picker("Estado", selection: $draft.readingStatus) {
                        Text("Por leer").tag(ReadingStatus.toRead)
                        Text("Leyendo").tag(ReadingStatus.reading)
                        Text("Leído").tag(ReadingStatus.finished)
                        Text("Abandonado").tag(ReadingStatus.abandoned)
                    }
                    HStack {
                        Text("Valoración")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                draft.rating = draft.rating == Double(star) ? nil : Double(star)
                            } label: {
                                Image(systemName: Double(star) <= (draft.rating ?? 0) ? "star.fill" : "star")
                                    .foregroundStyle(Theme.pencil)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(star) estrellas")
                        }
                    }
                }

                Section("Sinopsis") {
                    TextEditor(text: optional(\.summary))
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Editar datos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
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
            .alert("No se pudo guardar", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let newCover, let source = CGImageSourceCreateWithData(newCover as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 3))
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

    private func save() {
        var edited = draft
        edited.authors = authors.components(separatedBy: "&").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        edited.tags = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        edited.seriesIndex = edited.series == nil ? nil : Double(seriesIndex.replacingOccurrences(of: ",", with: "."))
        let cleanISBN = isbn.trimmingCharacters(in: .whitespaces)
        edited.identifiers["isbn"] = cleanISBN.isEmpty ? nil : cleanISBN
        do {
            try model.library.update(edited, cover: newCover)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
