import LectoraCore
import SwiftUI

struct ReviewInboxRef: Hashable {}

struct CandidatesRef: Hashable {
    let bookID: UUID
    /// Buscar de nuevo al abrir (desde la ficha: «Buscar en internet»).
    var searchesFirst = false
}

/// «Por revisar»: los libros cuyos datos de internet no fueron seguros.
struct ReviewScreen: View {
    @EnvironmentObject private var model: AppModel

    private var pending: [ShelfBook] {
        model.library.reviews.keys
            .compactMap { model.shelfBook(id: $0.uuidString) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Por revisar")
                Text("Encontré estos libros en internet, pero no estoy seguro de que sean los tuyos. Elige los datos correctos o conserva los que tienen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, Theme.Space.xs)
                if pending.isEmpty {
                    EmptyState(title: "Todo en orden", message: "No hay libros pendientes de revisar.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(pending) { book in
                            if let id = book.bookID {
                                NavigationLink(value: CandidatesRef(bookID: id)) {
                                    BookRow(book: book, detail: detail(for: id)) {
                                        Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, Theme.Space.l)
                }
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func detail(for id: UUID) -> String {
        let count = model.library.reviews[id]?.count ?? 0
        return count == 0 ? "No lo encontré en internet" : (count == 1 ? "1 posible coincidencia" : "\(count) posibles coincidencias")
    }
}

/// Elegir entre los libros encontrados, conservar tus datos o escribirlos a mano.
struct CandidatesScreen: View {
    let bookID: UUID
    var searchesFirst = false
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var applying: String?
    @State private var errorMessage: String?
    @State private var editing = false

    private var book: ShelfBook? { model.shelfBook(id: bookID.uuidString) }
    private var candidates: [MetadataCandidate] { model.library.reviews[bookID] ?? [] }
    private var searching: Bool { model.library.identifying.contains(bookID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(title: "Elige los datos")
                if let book {
                    Text("Tus datos ahora")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, Theme.Space.l)
                    BookRow(book: book, detail: book.author)
                }

                Group {
                    if searching {
                        HStack(spacing: Theme.Space.m) {
                            ProgressView()
                            Text("Buscando en Open Library y Google Books…")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(.vertical, Theme.Space.xl)
                    } else if candidates.isEmpty {
                        EmptyState(title: "No lo encontré",
                                   message: "Ninguna fuente tiene este libro. Puedes escribir los datos a mano.")
                    } else {
                        Text("Encontrados en internet")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                            .padding(.top, Theme.Space.xl)
                        LazyVStack(spacing: 0) {
                            ForEach(candidates) { candidate in
                                Button { choose(candidate) } label: {
                                    CandidateRow(candidate: candidate)
                                        .opacity(applying == nil || applying == candidate.id ? Theme.Emphasis.full : Theme.Emphasis.dimmed)
                                }
                                .buttonStyle(.plain)
                                .disabled(applying != nil)
                                .accessibilityHint("Usa estos datos para el libro")
                            }
                        }
                    }
                }

                VStack(spacing: Theme.Space.m) {
                    SecondaryButton(title: "Mantener mis datos") {
                        model.library.dismissReview(bookID)
                        dismiss()
                    }
                    SecondaryButton(title: "Escribir a mano", systemImage: "pencil") { editing = true }
                }
                .padding(.top, Theme.Space.xl)
            }
            .screenContent()
        }
        .background(Theme.paper.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if searchesFirst { await model.library.identify(bookID, askAlways: true) }
        }
        .sheet(isPresented: $editing) {
            if let record = model.library.book(id: bookID) { MetadataEditorView(book: record) }
        }
        .alert("No se pudo aplicar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func choose(_ candidate: MetadataCandidate) {
        applying = candidate.id
        Task {
            do {
                try await model.library.apply(candidate, to: bookID)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            applying = nil
        }
    }
}
