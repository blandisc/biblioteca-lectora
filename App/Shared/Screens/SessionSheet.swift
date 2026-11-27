import LectoraCore
import SwiftUI

/// «Esta sesión»: al tocar el contador del lector, una tarjeta de vidrio abajo
/// (no una hoja completa): los tres números, la barra de etapas con su leyenda y
/// «Escribir sobre ella». Todo a la vista, sin aire de sobra.
struct SessionCard: View {
    @ObservedObject var tracker: SessionTracker
    let bookTitle: String
    let close: () -> Void
    @State private var notice: String?
    @State private var writing: NoteRef?

    /// Las palabras, o «Acabas de empezar» mientras no haya ninguna.
    private func words(_ session: ReadingSession) -> String {
        session.words > 0 ? "\(ReadingFormat.words(session.words)) palabras" : "Acabas de empezar"
    }

    /// El tramo más largo, solo si dice algo que la leyenda no dice ya: con una
    /// sola etapa, su tiempo y el tramo son el mismo número.
    private func streak(_ session: ReadingSession) -> String? {
        let seconds = session.longestStreak
        let stages = ReadingStage.allCases.filter { session.seconds(in: $0) >= 30 }
        guard seconds >= 60, stages.count > 1 else { return nil }
        return "Tu tramo más largo sin interrupciones: \(ReadingFormat.duration(seconds))."
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let session = tracker.snapshot(at: context.date)
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                HStack {
                    SectionLabel(text: "Esta sesión")
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
                // El botón conserva su área de toque, pero no empuja lo de abajo.
                .padding(.vertical, -Theme.Size.tapBleed)
                if let session {
                    // Editorial: el tiempo en grande y, en la misma línea, el ritmo.
                    HStack(alignment: .lastTextBaseline) {
                        Text(ReadingFormat.clock(session.elapsed))
                            .font(.bookTitle)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Spacer(minLength: Theme.Space.l)
                        VStack(alignment: .trailing, spacing: Theme.Space.xxs) {
                            Text(words(session))
                            if let perMinute = session.wordsPerMinute, session.words > 0 {
                                Text("\(perMinute) por minuto")
                            }
                        }
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryInk)
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        StageBar(segments: session.segments, height: Theme.Size.stageBarThin)
                        StageLegend { session.seconds(in: $0) }
                        if let streak = streak(session) {
                            Text(streak)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    // Escribir es lo menos frecuente: un renglón discreto, no un botón.
                    VStack(spacing: 0) {
                        Divider()
                        Button {
                            write(session)
                        } label: {
                            HStack(spacing: Theme.Space.s) {
                                Label("Escribir sobre ella", systemImage: "square.and.pencil")
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(minHeight: Theme.Size.tapTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, -Theme.Space.s)
                } else {
                    Text("Empieza al pasar la página: cuenta palabras, tiempo y ritmo. Nada sale de tus dispositivos.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.Space.l)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Reader.chromeInset)
        .noteSheet(item: $writing)
        .sessionNoteError($notice)
    }

    private func write(_ session: ReadingSession) {
        do { writing = try SessionNote.open(session, bookTitle: bookTitle) } catch { notice = error.localizedDescription }
    }
}

/// «Sesión terminada»: aparece sobre la Mesa al cerrar el libro.
struct SessionSummarySheet: View {
    let session: ReadingSession
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?
    @State private var writing: NoteRef?

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
                    do { writing = try SessionNote.open(session, bookTitle: book?.title ?? "Sin título") } catch {
                        notice = error.localizedDescription
                    }
                }
                PrimaryButton(title: "Listo", fillsWidth: true) { dismiss() }
            }
        }
        .foregroundStyle(Theme.ink)
        .gutter()
        .padding(.top, Theme.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .pushedScreen()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .noteSheet(item: $writing)
        .sessionNoteError($notice)
    }

    private var progressLine: String {
        let title = book?.title ?? "Tu libro"
        let from = session.fromFraction.percentText
        let to = session.toFraction.percentText
        return from == to ? "\(title) · \(to)" : "\(title) · de \(from) a \(to)"
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
            VStack(alignment: .leading, spacing: Theme.Space.l) {
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
        let streak = max(0, session.longestStreak.safeInt ?? 0)
        let text = streak >= 60 ? "\(streak / 60) min \(streak % 60) s" : "\(streak) s"
        return "Tu tramo más largo sin interrupciones fue de \(text). La etapa mide cuánto sostienes la atención, no qué tan rápido lees."
    }
}

/// «Escribir sobre ella»: abre en el editor la nota de esa sesión. La primera vez la crea con
/// el resumen; las siguientes abre la misma (RB-7a, 26 nov 2026: creaba una nota en silencio,
/// no dejaba escribir, y dos toques daban dos notas iguales).
enum SessionNote {
    /// Qué nota se creó para cada sesión, en este dispositivo.
    private static let key = "sesiones.notas"

    @MainActor
    static func open(_ session: ReadingSession, bookTitle: String) throws -> NoteRef {
        let notes = NotesStore.shared
        var made = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let fileName = made[session.id.uuidString], notes.note(fileName: fileName) != nil {
            return NoteRef(fileName: fileName, writes: true)
        }
        let day = session.start.es(.dateTime.day().month(.wide))
        let text = """
        # \(bookTitle), \(day)

        Sesión de \(ReadingFormat.duration(session.readingSeconds)) en [[\(bookTitle)]]: \(ReadingFormat.words(session.words)) palabras, \(ReadingFormat.duration(session.seconds(in: .immersed))) inmersa.


        """
        guard let note = try notes.save(text: text, fileName: nil) else { return .new(draft: text) }
        made[session.id.uuidString] = note.fileName
        UserDefaults.standard.set(made, forKey: key)
        return NoteRef(fileName: note.fileName, writes: true)
    }
}

extension View {
    /// La nota de una sesión, en su propia hoja con el editor abierto.
    func noteSheet(item: Binding<NoteRef?>) -> some View {
        sheet(item: item) { ref in
            NavigationStack {
                NoteScreen(ref: ref)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar la nota") { item.wrappedValue = nil }
                        }
                    }
            }
        }
    }

    /// Si la nota no se pudo crear, por qué.
    func sessionNoteError(_ message: Binding<String?>) -> some View {
        alert("No se pudo crear la nota", isPresented: Binding(get: { message.wrappedValue != nil },
                                                             set: { if !$0 { message.wrappedValue = nil } })) {
            Button("Volver a la sesión", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
