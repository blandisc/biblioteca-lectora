import SwiftUI

/// El mini reproductor vive sobre la barra de pestañas (iOS 26). En versiones
/// anteriores no se muestra; el audio seguirá en la pantalla de bloqueo. Hasta que
/// haya audio (`Features.audiobook`) no se muestra en ningún lado.
struct MiniPlayerAccessory: ViewModifier {
    let book: ShelfBook?

    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.2)
        if #available(iOS 26.0, *), Features.audiobook, let book {
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
/// dentro de un anillo de avance y +30 s. Solo interfaz por ahora: escondido tras `Features.audiobook`.
struct MiniPlayer: View {
    let book: ShelfBook
    @State private var playing = true
    private let chapterProgress = 0.38

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            CoverView(title: book.title, author: book.author, style: book.cover, image: book.coverImage)
                .frame(width: Theme.Size.coverMini)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(book.title)
                    .font(.rowTitle.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Theme.Space.s) {
                    if playing { EqualizerBars() }
                    Text("Cap. VII · quedan 18 min")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
            PlayRingButton(playing: playing, progress: chapterProgress) { playing.toggle() }
            Button {} label: {
                Image(systemName: "goforward.30").font(.icon.weight(.medium))
                    .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            }
            .accessibilityLabel("Adelantar 30 segundos")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.l)
    }
}
