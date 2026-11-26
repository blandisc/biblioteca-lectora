import LectoraCore
import SwiftUI

extension Slit.Unit: @retroactive Identifiable {
    public var id: Self { self }

    var name: String {
        switch self {
        case .phrase: "Frase"
        case .word: "Palabra"
        }
    }
}

/// La hendidura (HE-A y HE-B): el texto pasa por una ranura a media pantalla,
/// un pedazo a la vez, con lo de antes y lo de después en tenue. Tocar pausa;
/// deslizar a la derecha regresa un pedazo y a la izquierda adelanta. Al cerrar,
/// el libro queda donde ibas.
struct SlitScreen: View {
    let controller: ReaderController
    let paper: Color
    let ink: Color
    let close: () -> Void

    @AppStorage(ReaderKeys.slitUnit) private var unit: Slit.Unit = .phrase
    @AppStorage(ReaderKeys.slitPace) private var pace = Slit.defaultWordsPerMinute
    @State private var text = ""
    @State private var chunks: [Slit.Chunk] = []
    @State private var index = 0
    @State private var playing = false
    @State private var finished = false
    @State private var loading = true

    private var current: Slit.Chunk? { chunks.indices.contains(index) ? chunks[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { leave() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                        .glassCircle()
                }
                .accessibilityLabel("Terminar la hendidura")
                Spacer()
            }
            .padding(.horizontal, Theme.Reader.chromeInset)

            Spacer(minLength: 0)
            slit
            Spacer(minLength: 0)

            controls
                .padding(.horizontal, Theme.Reader.textMargin)
                .padding(.bottom, Theme.Space.l)
        }
        .foregroundStyle(ink)
        .background(paper.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { if !finished { playing.toggle() } }
        .gesture(
            DragGesture(minimumDistance: Theme.Reader.slitSwipe)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    step(value.translation.width > 0 ? -1 : 1)
                }
        )
        .sensoryFeedback(.selection, trigger: playing)
        .task { await load(nextChapter: false) }
        .task(id: playing) { await run() }
        .onChange(of: unit) { _, _ in rechunk() }
    }

    /// La ranura: lo de antes en tenue, el pedazo entre dos filos y lo que sigue en tenue.
    private var slit: some View {
        VStack(spacing: Theme.Space.s) {
            Text(context(before: true))
                .font(.prose)
                .foregroundStyle(ink.opacity(Theme.Emphasis.aside))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            VStack(spacing: 0) {
                Hairline()
                Group {
                    if finished {
                        Text("Fin del capítulo").font(.bookTitle).foregroundStyle(ink)
                    } else if let current {
                        SlitText(text: current.text, focus: unit == .word ? Slit.focusIndex(of: current.text) : nil, ink: ink)
                    } else {
                        Text(loading ? "Abriendo…" : "").font(.bookTitle)
                    }
                }
                .padding(.vertical, Theme.Reader.slitPadding)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
                .animation(Theme.Motion.press, value: index)
                Hairline()
            }
            Text(context(before: false))
                .font(.prose)
                .foregroundStyle(ink.opacity(Theme.Emphasis.aside))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(.horizontal, Theme.Reader.textMargin)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: Theme.Space.l) {
            if finished {
                PrimaryButton(title: "Seguir con el siguiente capítulo") {
                    Task { await load(nextChapter: true) }
                }
            } else {
                // Por frase (HE-B) o palabra por palabra (HE-A): se cambia sin perder el lugar.
                FilterBar(items: Array(Slit.Unit.allCases.reversed()), selection: $unit) { $0.name }
                HStack(spacing: Theme.Space.l) {
                    Button { pace = max(Slit.wordsPerMinuteRange.lowerBound, pace - Slit.wordsPerMinuteStep) } label: {
                        Image(systemName: "minus").roundInGlass()
                    }
                    .accessibilityLabel("Más despacio")
                    Text("\(pace) palabras/min")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                    Button { pace = min(Slit.wordsPerMinuteRange.upperBound, pace + Slit.wordsPerMinuteStep) } label: {
                        Image(systemName: "plus").roundInGlass()
                    }
                    .accessibilityLabel("Más rápido")
                }
                Text(playing ? "Toca para pausar · desliza para regresar" : "Toca para empezar")
                    .font(.footnote)
                    .foregroundStyle(ink.opacity(Theme.Emphasis.folioMuted))
            }
        }
        .buttonStyle(.plain)
    }

    private func context(before: Bool) -> String {
        guard !chunks.isEmpty else { return "" }
        let range = before
            ? max(0, index - Theme.Reader.slitContext)..<index
            : min(chunks.count, index + 1)..<min(chunks.count, index + 1 + Theme.Reader.slitContext)
        return chunks[range].map(\.text).joined(separator: " ")
    }

    private func load(nextChapter: Bool) async {
        loading = true
        defer { loading = false }
        guard let fresh = await controller.slitText(nextChapter: nextChapter) else {
            if nextChapter { leave() }
            return
        }
        text = fresh
        chunks = Slit.chunks(fresh, unit: unit)
        index = 0
        finished = chunks.isEmpty
        playing = nextChapter
    }

    /// Cambiar de frase a palabra (o al revés) sigue en el mismo lugar del texto.
    private func rechunk() {
        let offset = current?.offset ?? 0
        chunks = Slit.chunks(text, unit: unit)
        index = Slit.index(atOffset: offset, in: chunks)
    }

    private func step(_ delta: Int) {
        guard !chunks.isEmpty else { return }
        finished = false
        index = min(max(0, index + delta), chunks.count - 1)
    }

    private func run() async {
        while playing, let current {
            try? await Task.sleep(for: .seconds(Slit.duration(of: current, wordsPerMinute: pace)))
            guard playing, !Task.isCancelled else { return }
            if index + 1 < chunks.count {
                index += 1
            } else {
                playing = false
                finished = true
            }
        }
    }

    private func leave() {
        playing = false
        controller.slitGoTo(offset: current?.offset ?? 0)
        close()
    }
}
