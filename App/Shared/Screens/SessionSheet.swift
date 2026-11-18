import LectoraCore
import SwiftUI

/// «Sesión actual»: al tocar el contador del lector. Palabras, tiempo, ritmo y
/// las etapas hasta ahora; «Escribir sobre ella» deja una nota en el Cuaderno.
struct SessionSheet: View {
    @ObservedObject var tracker: SessionTracker
    let bookTitle: String
    let fraction: Double
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    if let session = tracker.snapshot(at: context.date) {
                        SessionDetail(session: session, bookTitle: bookTitle, fraction: fraction, live: true) {
                            notice = SessionNote.write(session, bookTitle: bookTitle)
                        }
                        .screenContent()
                    } else {
                        EmptyState(title: "Tu sesión empieza al pasar la página",
                                   message: "Gabinete cuenta las páginas que lees, cuánto tiempo y a qué ritmo. Nada sale de tus dispositivos.")
                            .screenContent()
                    }
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Sesión actual")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }.foregroundStyle(Theme.accent)
                }
            }
            .alert("Nota", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
        .presentationDetents([.large])
    }
}

/// «Sesión terminada»: aparece sobre la Mesa al cerrar el libro.
struct SessionSummarySheet: View {
    let session: ReadingSession
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?

    private var book: ShelfBook? { model.shelfBook(id: session.bookID.uuidString) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    SectionLabel(text: "Sesión terminada")
                    Spacer()
                    ShareSessionButton(card: ShareCard(session: session, title: book?.title ?? "", author: book?.author ?? ""))
                        .foregroundStyle(Theme.ink)
                }
                Text("\(ReadingFormat.duration(session.readingSeconds)) de lectura")
                    .font(.bookTitle)
                Text(progressLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                StageBar(segments: session.segments)
                HStack {
                    Text(session.start.es(.dateTime.hour().minute()))
                    Spacer()
                    Text(session.end.es(.dateTime.hour().minute()))
                }
                .font(.caption)
                .foregroundStyle(Theme.tertiaryInk)
            }
            StatTrio(items: [
                .init(value: ReadingFormat.words(session.words), label: "palabras"),
                .init(value: ReadingFormat.duration(session.seconds(in: .immersed)), label: "inmersa"),
                .init(value: session.wordsPerMinute.map(String.init) ?? "—", label: "palabras/min"),
            ])
            HStack(spacing: Theme.Space.s) {
                SecondaryButton(title: "Escribir sobre ella") {
                    notice = SessionNote.write(session, bookTitle: book?.title ?? "Sin título")
                }
                PrimaryButton(title: "Listo", fillsWidth: true) { dismiss() }
            }
        }
        .foregroundStyle(Theme.ink)
        .gutter()
        .padding(.top, Theme.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.paper.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .alert("Nota", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(notice ?? "")
        }
    }

    private var progressLine: String {
        let title = book?.title ?? "Tu libro"
        let from = Int((session.fromFraction * 100).rounded())
        let to = Int((session.toFraction * 100).rounded())
        return from == to ? "\(title) · \(to) %" : "\(title) · de \(from) % a \(to) %"
    }
}

/// Los números y las etapas de una sesión (en curso o pasada).
struct SessionDetail: View {
    let session: ReadingSession
    let bookTitle: String
    let fraction: Double
    var live = false
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(bookTitle)
                    .font(.rowTitle)
                HStack(spacing: Theme.Space.s) {
                    ThinProgress(value: fraction)
                    Text((fraction).percentText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            StatTrio(items: [
                .init(value: ReadingFormat.words(session.words), label: "palabras"),
                .init(value: live ? ReadingFormat.clock(session.elapsed) : ReadingFormat.duration(session.readingSeconds),
                      label: live ? "minutos" : "leyendo"),
                .init(value: session.wordsPerMinute.map(String.init) ?? "—", label: "palabras/min"),
            ])
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "Etapas")
                    Spacer()
                    let immersed = session.seconds(in: .immersed)
                    if immersed >= 60 {
                        Text("\(ReadingFormat.duration(immersed)) inmersa")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                StageChart(segments: session.segments)
                Text(streakLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            SecondaryButton(title: "Escribir sobre ella", systemImage: "square.and.pencil", action: onWrite)
        }
        .foregroundStyle(Theme.ink)
    }

    private var streakLine: String {
        let streak = Int(session.longestStreak)
        let text = streak >= 60 ? "\(streak / 60) min \(streak % 60) s" : "\(streak) s"
        return "Tu tramo más largo sin interrupciones fue de \(text). La etapa mide cuánto sostienes la atención, no qué tan rápido lees."
    }
}

/// «Escribir sobre ella»: una nota nueva en el Cuaderno con el resumen de la sesión.
enum SessionNote {
    @MainActor
    static func write(_ session: ReadingSession, bookTitle: String) -> String {
        let day = session.start.es(.dateTime.day().month(.wide))
        let text = """
        # \(bookTitle), \(day)

        Sesión de \(ReadingFormat.duration(session.readingSeconds)) en [[\(bookTitle)]]: \(ReadingFormat.words(session.words)) palabras, \(ReadingFormat.duration(session.seconds(in: .immersed))) inmersa.


        """
        do {
            let note = try NotesStore.shared.save(text: text, fileName: nil)
            return "Se creó la nota «\(note?.title ?? bookTitle)» en el Cuaderno."
        } catch {
            return "No se pudo crear la nota: \(error.localizedDescription)"
        }
    }
}
