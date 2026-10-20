import SwiftUI

/// El mini reproductor vive sobre la barra de pestañas (iOS 26). En versiones
/// anteriores no se muestra; el audio seguirá en la pantalla de bloqueo.
struct MiniPlayerAccessory: ViewModifier {
    let book: ShelfBook?

    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.2)
        if #available(iOS 26.0, *), let book {
            content.tabViewBottomAccessory { MiniPlayer(book: book) }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Portada, título, capítulo con barritas que se mueven mientras suena, pausa
/// dentro de un anillo de avance y +30 s. Solo interfaz por ahora.
struct MiniPlayer: View {
    let book: ShelfBook
    @State private var playing = true
    private let chapterProgress = 0.38

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            CoverView(title: book.title, author: book.author, style: book.cover, image: book.coverImage)
                .frame(width: Theme.Size.coverMini)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(book.title)
                    .font(.rowTitle.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Theme.Space.xs + Theme.Space.xxs) {
                    if playing { EqualizerBars() }
                    Text("Cap. VII · quedan 18 min")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
            Button { playing.toggle() } label: {
                ZStack {
                    Circle().stroke(Theme.track, lineWidth: Theme.Size.quoteRule)
                    Circle().trim(from: 0, to: chapterProgress)
                        .stroke(Theme.pencil, style: StrokeStyle(lineWidth: Theme.Size.quoteRule, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(width: Theme.Size.tapTarget - Theme.Space.s + Theme.Space.xxs, height: Theme.Size.tapTarget - Theme.Space.s + Theme.Space.xxs)
                .contentShape(Circle())
            }
            .accessibilityLabel(playing ? "Pausa" : "Reproducir")
            Button {} label: {
                Image(systemName: "goforward.30").font(.title3.weight(.medium))
                    .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            }
            .accessibilityLabel("Adelantar 30 segundos")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.m)
    }
}

private struct EqualizerBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.xxs) {
            ForEach([0.5, 1.0, 0.7], id: \.self) { height in
                Capsule()
                    .fill(Theme.pencil)
                    .frame(width: Theme.Space.xxs, height: Theme.Space.m * height)
                    .phaseAnimator([1.0, 0.4]) { bar, phase in
                        bar.scaleEffect(y: phase, anchor: .bottom)
                    } animation: { _ in .easeInOut(duration: 0.45 + height * 0.2) }
            }
        }
        .frame(height: Theme.Space.m, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
