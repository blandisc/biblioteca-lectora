import SwiftUI

/// Portada de respaldo para libros sin imagen: color, tipografía y, a veces,
/// una ilustración a línea. Tiene lomo (sombra en el borde izquierdo) para
/// que se lea como un objeto.
/// Los colores de una portada son fijos: no cambian con el modo oscuro.
struct CoverStyle: Hashable {
    enum Illustration: Hashable {
        case none
        case windmill
        case circles
        case rings
    }

    var background: Color
    var foreground: Color
    var illustration: Illustration = .none
    /// Filo fino para portadas claras sobre fondo claro.
    var bordered = false
}

struct CoverView: View {
    let title: String
    let author: String
    let style: CoverStyle
    var showsRibbon = false
    /// `cover.jpg` del libro; sin imagen, se dibuja la portada tipográfica.
    var image: URL? = nil
    /// Portada nítida (la Mesa la pide para todo lo que muestra).
    @Environment(\.crispCovers) private var crisp

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                if let image, let picture = CoverImaging.image(at: image) {
                    if Self.fills(picture) {
                        Image(decorative: picture, scale: 1).resizable().scaledToFill()
                            .frame(width: width, height: proxy.size.height)
                            .clipped()
                    } else {
                        // Cuadrada o apaisada: entera, sin estirarse ni recortarse.
                        FittedCover(image: Image(decorative: picture, scale: 1))
                    }
                } else {
                style.background
                VStack(alignment: style.illustration == .windmill ? .center : .leading, spacing: width * Theme.CoverArt.gap) {
                    if style.illustration == .windmill {
                        Text(author.uppercased())
                            .font(.system(size: width * Theme.CoverArt.authorTop)) // ds-exception: portada dibujada
                            .spaced(Theme.CoverArt.authorTracking, author)
                    }
                    // Sin partir una palabra (regla 9): si la más ancha no cabe, la letra baja un paso.
                    WholeWordsText(title) { scale in
                        .system(size: width * Theme.CoverArt.title * scale, design: .serif) // ds-exception: portada dibujada
                    }
                        .italic(style.illustration == .windmill)
                        .multilineTextAlignment(style.illustration == .windmill ? .center : .leading)
                        .lineLimit(4)
                        .minimumScaleFactor(Theme.CoverArt.titleMinScale)
                    Spacer(minLength: 0)
                    illustration(width: width)
                    if style.illustration != .windmill {
                        Text(author.uppercased())
                            .font(.system(size: width * Theme.CoverArt.author)) // ds-exception: portada dibujada
                            .spaced(Theme.CoverArt.authorTracking, author)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(style.foreground)
                .padding(width * Theme.CoverArt.inset)
                .padding(.trailing, showsRibbon ? width * Theme.CoverArt.ribbonClear : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.illustration == .windmill ? .top : .topLeading)
                }

                LinearGradient(colors: [Theme.shade.opacity(Theme.CoverArt.spineShade), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: max(Theme.CoverArt.spineMin, width * Theme.CoverArt.spine))

                if showsRibbon {
                    Ribbon()
                        .fill(Theme.accent)
                        .frame(width: max(Theme.CoverArt.ribbonMin, width * Theme.CoverArt.ribbon),
                               height: proxy.size.height + Theme.CoverArt.ribbonOverhang)
                        .offset(x: width * Theme.CoverArt.ribbonX, y: -Theme.CoverArt.ribbonRise)
                        .shadow(color: Theme.shade.opacity(Theme.CoverArt.ribbonShade), radius: Theme.CoverArt.thinLine, y: Theme.CoverArt.thinLine)
                }
            }
            .clipShape(coverShape)
            .overlay {
                if crisp {
                    coverShape
                        .strokeBorder(Theme.ink.opacity(Theme.CoverArt.crispEdge), lineWidth: Theme.Size.hairline)
                } else if style.bordered {
                    coverShape
                        .strokeBorder(Theme.shade.opacity(Theme.CoverArt.edgeLine), lineWidth: Theme.Size.hairline)
                }
            }
        }
        .aspectRatio(Theme.Size.coverAspect, contentMode: .fit)
        .shadow(color: Theme.shade.opacity(crisp ? Theme.CoverArt.crispShadow : Theme.CoverArt.shadow),
                radius: crisp ? Theme.CoverArt.crispShadowRadius : Theme.CoverArt.shadowRadius,
                x: 0, y: crisp ? Theme.CoverArt.crispShadowY : Theme.CoverArt.shadowY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), de \(author)")
    }

    /// ¿La imagen es (casi) 2∶3? Entonces llena el marco; si no, cabe entera (UX-2e).
    static func fills(_ picture: CGImage) -> Bool {
        guard picture.height > 0 else { return true }
        let aspect = CGFloat(picture.width) / CGFloat(picture.height)
        return abs(aspect - Theme.Size.coverAspect) / Theme.Size.coverAspect <= Theme.CoverArt.fitTolerance
    }

    private var coverShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: Theme.CoverArt.spineRadius, bottomLeadingRadius: Theme.CoverArt.spineRadius,
                               bottomTrailingRadius: Theme.CoverArt.edgeRadius, topTrailingRadius: Theme.CoverArt.edgeRadius)
    }

    @ViewBuilder
    private func illustration(width: CGFloat) -> some View {
        switch style.illustration {
        case .none:
            EmptyView()
        case .windmill:
            Windmill()
                .stroke(style.foreground, style: StrokeStyle(lineWidth: Theme.CoverArt.line, lineCap: .round, lineJoin: .round))
                .frame(width: width * Theme.CoverArt.windmill.width, height: width * Theme.CoverArt.windmill.height)
        case .circles:
            HStack(spacing: -width * Theme.CoverArt.circlesOverlap) {
                Circle().fill(style.foreground)
                Circle().stroke(style.foreground, lineWidth: Theme.CoverArt.line)
            }
            .frame(width: width * Theme.CoverArt.circles.width, height: width * Theme.CoverArt.circles.height)
        case .rings:
            ZStack {
                Circle().stroke(style.foreground, lineWidth: Theme.CoverArt.thinLine)
                Circle().stroke(style.foreground, lineWidth: Theme.CoverArt.thinLine).padding(width * Theme.CoverArt.ringGap)
                Circle().fill(style.foreground).frame(width: width * Theme.CoverArt.ringDot)
            }
            .frame(width: width * Theme.CoverArt.rings, height: width * Theme.CoverArt.rings)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Cinta de lectura con la punta en cola de golondrina.
struct Ribbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Molino de viento a línea (portada del Quijote).
struct Windmill: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 96, sy = rect.height / 104
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(40, 100)); path.addLine(to: p(44, 46)); path.addLine(to: p(52, 46)); path.addLine(to: p(56, 100))
        for end in [p(22, 8), p(86, 22), p(74, 82), p(10, 64)] {
            path.move(to: p(48, 44)); path.addLine(to: end)
        }
        path.move(to: p(2, 100))
        path.addCurve(to: p(94, 99), control1: p(30, 97), control2: p(66, 102))
        return path
    }
}

/// Portadas nítidas: filo fino y sombra larga y tenue en vez de la sombra de objeto (ME-1).
private struct CrispCoversKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var crispCovers: Bool {
        get { self[CrispCoversKey.self] }
        set { self[CrispCoversKey.self] = newValue }
    }
}
