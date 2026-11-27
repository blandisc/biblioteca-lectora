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
    /// La forma de la ventana: en un pliego, la ranura en la página izquierda y los controles en la
    /// derecha. Antes la palabra que se lee caía justo en el pliegue (ronda 0).
    var window = WindowLayout()
    let close: () -> Void

    @AppStorage(ReaderKeys.slitUnit) private var unit: Slit.Unit = .phrase
    @AppStorage(ReaderKeys.slitPace) private var pace = Slit.defaultWordsPerMinute
    @State private var text = ""
    @State private var chunks: [Slit.Chunk] = []
    @State private var index = 0
    @State private var playing = false
    @State private var finished = false
    @State private var loading = true
    /// Solo tus toques vibran: que el capítulo se acabe no (la lectura nunca vibra sola).
    @State private var taps = 0

    private var current: Slit.Chunk? { chunks.indices.contains(index) ? chunks[index] : nil }
    /// PR-1: mientras corre solo queda la ranura; al pausar vuelven la ✕ y los controles.
    private var showsControls: Bool { !playing || finished }

    var body: some View {
        Group {
            if let fold = window.verticalFold {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        closeRow
                        Spacer(minLength: 0)
                        slit.padding(.horizontal, Theme.Reader.textMargin)
                        Spacer(minLength: 0)
                    }
                    .frame(width: fold.position - window.leading)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        controlBar
                    }
                }
            } else {
                VStack(spacing: 0) {
                    closeRow
                    Spacer(minLength: 0)
                    slit
                    Spacer(minLength: 0)
                    controlBar
                }
            }
        }
        .animation(Theme.Motion.standard, value: showsControls)
        .foregroundStyle(ink)
        .background(paper.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            guard !finished else { return }
            playing.toggle()
            taps += 1
        }
        .gesture(
            DragGesture(minimumDistance: Theme.Reader.slitSwipe)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    step(value.translation.width > 0 ? -1 : 1)
                }
        )
        .sensoryFeedback(.selection, trigger: taps)
        #if os(iOS)
        // Mientras corre sola nadie toca la pantalla: que no se apague a media frase.
        .onChange(of: playing) { _, now in UIApplication.shared.isIdleTimerDisabled = now }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .task { await load(nextChapter: false) }
        .task(id: playing) { await run() }
        .onChange(of: unit) { _, _ in rechunk() }
    }

    private var closeRow: some View {
        HStack {
            CloseButton(label: "Terminar la hendidura", style: .glass) { leave() }
            Spacer()
        }
        .padding(.horizontal, Theme.Reader.chromeInset)
        .opacity(showsControls ? Theme.Emphasis.rest : 0)
        .allowsHitTesting(showsControls)
        .accessibilityHidden(!showsControls)
    }

    private var controlBar: some View {
        controls
            .padding(.horizontal, Theme.Reader.textMargin)
            .padding(.bottom, Theme.Space.l)
            .opacity(showsControls ? Theme.Emphasis.rest : 0)
            .allowsHitTesting(showsControls)
            .accessibilityHidden(!showsControls)
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
                // El mismo alto por frase o por palabra: los filos no brincan al cambiar.
                .frame(maxWidth: .infinity, minHeight: Theme.Reader.slitHeight)
                .padding(.vertical, Theme.Reader.slitPadding)
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
                // Una sola fila: por frase (HE-B) o palabra (HE-A) a la izquierda, como en toda
                // la app, y la velocidad a la derecha.
                // Con la letra más grande, la velocidad baja bajo frase o palabra.
                AdaptiveStack(spacing: Theme.Space.l) {
                    FilterBar(items: Array(Slit.Unit.allCases.reversed()), selection: $unit) { $0.name }
                    pacer.layoutPriority(1)
                }
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(ink.opacity(Theme.Emphasis.folioMuted))
            }
        }
        .buttonStyle(.plain)
    }

    /// − 260 palabras/min +: la cifra arriba y su unidad chica abajo, entre los dos botones.
    private var pacer: some View {
        HStack(spacing: Theme.Space.s) {
            Button { pace = max(Slit.wordsPerMinuteRange.lowerBound, pace - Slit.wordsPerMinuteStep) } label: {
                Image(systemName: "minus").roundInGlass()
            }
            .accessibilityLabel("Más despacio")
            VStack(spacing: 0) {
                Text("\(pace)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("palabras/min")
                    .font(.caption)
                    .foregroundStyle(ink.opacity(Theme.Emphasis.folioMuted))
            }
            .lineLimit(1)
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
            .animation(Theme.Motion.select, value: pace)
            Button { pace = min(Slit.wordsPerMinuteRange.upperBound, pace + Slit.wordsPerMinuteStep) } label: {
                Image(systemName: "plus").roundInGlass()
            }
            .accessibilityLabel("Más rápido")
        }
    }

    private var hint: String {
        index == 0 ? "Toca para empezar · desliza para mover" : "Toca para seguir · desliza para regresar"
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
