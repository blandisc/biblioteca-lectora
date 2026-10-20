import SwiftUI

/// Inicio (v7-Leyendo): el libro actual y lo que tienes en la mesa.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    CurrentBookCard(book: model.currentBook, onContinue: model.continueReading)
                    if !model.desk.isEmpty {
                        DeskSection(books: model.desk)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(Theme.groupedBackground.ignoresSafeArea())
            .navigationTitle("Leyendo")
            .navigationDestination(for: ShelfBook.self) { BookDetailView(book: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showsAccount = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Cuenta y conexiones")
                }
            }
            .sheet(isPresented: $showsAccount) { AccountView() }
        }
    }
}

private struct CurrentBookCard: View {
    let book: ShelfBook
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Button(action: onContinue) {
                    ShelfCover(book: book, showsRibbon: book.isReading)
                        .frame(width: 104)
                }
                .buttonStyle(PressableStyle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .font(.serifTitle(20))
                        .lineLimit(3)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, 3)
                    Spacer(minLength: 12)
                    if let note = book.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    HStack(spacing: 8) {
                        ThinProgress(value: book.progress)
                        Text(book.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: onContinue) {
                    Label("Seguir leyendo", systemImage: "book.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.onInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Button {} label: {
                    Image(systemName: "headphones")
                        .font(.title3)
                        .foregroundStyle(Theme.ink)
                        .frame(width: 48, height: 48)
                        .background(Theme.groupedBackground, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Escuchar desde aquí")
            }
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

private struct DeskSection: View {
    let books: [ShelfBook]
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("En tu mesa")
                .font(.title3.bold())
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            VStack(alignment: .leading, spacing: 6) {
                                ShelfCover(book: book)
                                ThinProgress(value: book.progress, height: 2)
                                Text(book.caption)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryInk)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
    }
}
