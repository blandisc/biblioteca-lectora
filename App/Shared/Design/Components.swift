import SwiftUI

/// Barra de progreso fina (4 pt en la tarjeta, 2 pt bajo las portadas).
struct ThinProgress: View {
    let value: Double
    var height: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(Theme.track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Progreso")
            .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

/// Respuesta al toque: se hunde un poco, sin cambiar de color.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Portada con la nube cuando el libro no está descargado.
struct ShelfCover: View {
    let book: ShelfBook
    var showsRibbon = false

    var body: some View {
        CoverView(title: book.title, author: book.author, style: book.cover, showsRibbon: showsRibbon)
            .overlay(alignment: .bottomTrailing) {
                if book.inCloudOnly {
                    Image(systemName: "icloud")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(5)
                        .background(.regularMaterial, in: Circle())
                        .padding(5)
                        .accessibilityLabel("En iCloud")
                }
            }
    }
}

/// Ficha de un libro (v7-Libro, versión mínima).
struct BookDetailView: View {
    let book: ShelfBook
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ShelfCover(book: book)
                    .frame(width: 168)
                    .padding(.top, 12)
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.serifTitle(26))
                        .multilineTextAlignment(.center)
                    Text(book.author)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                }
                if book.isReading {
                    HStack(spacing: 8) {
                        ThinProgress(value: book.progress)
                        Text(book.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: 240)
                }
                Button {
                    model.open(book)
                } label: {
                    Text(book.file != nil ? (book.isReading ? "Seguir leyendo" : "Leer") : "Aún no está en este dispositivo")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(book.file != nil ? Color.white : Theme.secondaryInk)
                        .background(book.file != nil ? Theme.ink : Theme.track, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(book.file == nil)
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.groupedBackground.ignoresSafeArea())
    }
}
