import SwiftUI
import UniformTypeIdentifiers

/// Pantalla provisional de la prueba S1: abrir un libro desde Archivos o Finder.
/// Se reemplaza por la biblioteca real cuando entre la sincronización (S3).
struct SpikeLibraryView: View {
    @State private var importing = false
    @State private var openBook: URL?
    @State private var recent: [URL] = SpikeStorage.recentBooks()
    @State private var importError: String?

    private static let readableTypes: [UTType] = [
        UTType(filenameExtension: "epub"),
        UTType(filenameExtension: "mobi"),
        UTType(filenameExtension: "azw3"),
        UTType(filenameExtension: "fb2"),
        UTType(filenameExtension: "cbz"),
    ].compactMap { $0 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        importing = true
                    } label: {
                        Label("Abrir un libro…", systemImage: "plus.circle")
                    }
                }
                if !recent.isEmpty {
                    Section("Recientes") {
                        ForEach(recent, id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) { openBook = url }
                        }
                    }
                }
            }
            .navigationTitle("Biblioteca Lectora")
            .navigationDestination(item: $openBook) { url in
                ReaderView(bookFile: url)
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: Self.readableTypes) { result in
                do {
                    let local = try SpikeStorage.importBook(from: result.get())
                    recent = SpikeStorage.recentBooks()
                    openBook = local
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("No se pudo importar", isPresented: .constant(importError != nil)) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }
}

/// Copias locales de los libros abiertos durante la prueba.
enum SpikeStorage {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spike", isDirectory: true)
    }

    static func importBook(from source: URL) throws -> URL {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func recentBooks() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return files.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }
}
