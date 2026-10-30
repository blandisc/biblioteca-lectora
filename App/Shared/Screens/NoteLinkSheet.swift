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
                        SectionLabel(text: "Nota nueva")
                        HStack(spacing: Theme.Space.m) {
                            TextField("Notas sobre \(bookTitle)", text: $newTitle)
                                .font(.rowTitle)
                            Button("Crear") { save(to: nil) }
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.brand)
                        }
                        .padding(.vertical, Theme.Space.s)
                        .overlay(alignment: .bottom) { Hairline() }
                    }

                    if !linking.isEmpty { section("Notas de este libro", linking) }
                    if !others.isEmpty { section("Otras", others) }
                }
                .screenContent()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Llevar a una nota")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
            .alert("No se pudo guardar", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(_ title: String, _ items: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title)
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
