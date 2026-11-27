import LectoraCore
import SwiftUI

/// «Llevar a una nota» desde el lector: la cita se añade al final de una nota
/// (primero las que ya enlazan este libro) o abre una nota nueva.
struct NoteLinkSheet: View {
    let annotation: Annotation
    let bookTitle: String
    var onSaved: (Note) -> Void = { _ in }
    @ObservedObject private var notes = NotesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle = ""
    @State private var errorMessage: String?

    private var linking: [Note] { notes.notes(linking: bookTitle) }
    private var others: [Note] { notes.notes.filter { !$0.links(bookTitle: bookTitle) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    QuoteBlock(text: annotation.quote, italic: true)
                        .lineLimit(3)

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        SectionHeader("Nota nueva")
                        HStack(spacing: Theme.Space.l) {
                            TextField("Notas sobre \(bookTitle)", text: $newTitle)
                                .font(.rowTitle)
                            TextAction(title: "Crear nota") { save(to: nil) }
                        }
                        .padding(.vertical, Theme.Space.s)
                        .overlay(alignment: .bottom) { Hairline() }
                    }

                    if !linking.isEmpty { section("Notas de este libro", linking) }
                    if !others.isEmpty { section("Otras", others) }
                }
                .screenContent()
            }
            .pushedScreen("Llevar a una nota")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BarButton("Dejar el pasaje") { dismiss() } }
            }
            .errorAlert("No pude guardar el pasaje", message: $errorMessage, back: "Elegir otra nota")
        }
        .presentationDetents([.medium, .large])
    }

    private func section(_ title: String, _ items: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title)
            ForEach(items) { note in
                Button { save(to: note.fileName) } label: { NoteRow(note: note) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func save(to fileName: String?) {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        do {
            if let saved = try notes.add(annotation, bookTitle: bookTitle, to: fileName,
                                         newTitle: title.isEmpty ? "Notas sobre \(bookTitle)" : title) {
                onSaved(saved)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
