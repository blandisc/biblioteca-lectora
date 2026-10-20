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

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                style.background
                VStack(alignment: style.illustration == .windmill ? .center : .leading, spacing: width * 0.05) {
                    if style.illustration == .windmill {
                        Text(author.uppercased())
                            .font(.system(size: width * 0.06))
                            .tracking(0.6)
                    }
                    Text(title)
                        .font(.system(size: width * 0.14, design: .serif))
                        .italic(style.illustration == .windmill)
                        .multilineTextAlignment(style.illustration == .windmill ? .center : .leading)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    illustration(width: width)
                    if style.illustration != .windmill {
                        Text(author.uppercased())
                            .font(.system(size: width * 0.07))
                            .tracking(0.6)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(style.foreground)
                .padding(width * 0.09)
                .padding(.trailing, showsRibbon ? width * 0.1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.illustration == .windmill ? .top : .topLeading)

                LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: max(3, width * 0.05))

                if showsRibbon {
                    Ribbon()
                        .fill(Theme.pencil)
                        .frame(width: max(5, width * 0.065), height: proxy.size.height + 22)
                        .offset(x: width * 0.88, y: -3)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 4, topTrailingRadius: 4))
            .overlay {
                if style.bordered {
                    UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 4, topTrailingRadius: 4)
                        .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
                }
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.28), radius: 7, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), de \(author)")
    }

    @ViewBuilder
    private func illustration(width: CGFloat) -> some View {
        switch style.illustration {
        case .none:
            EmptyView()
        case .windmill:
            Windmill()
                .stroke(style.foreground, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .frame(width: width * 0.55, height: width * 0.6)
        case .circles:
            HStack(spacing: -width * 0.12) {
                Circle().fill(style.foreground)
                Circle().stroke(style.foreground, lineWidth: 1.2)
            }
            .frame(width: width * 0.6, height: width * 0.3)
        case .rings:
            ZStack {
                Circle().stroke(style.foreground, lineWidth: 1)
                Circle().stroke(style.foreground, lineWidth: 1).padding(width * 0.1)
                Circle().fill(style.foreground).frame(width: width * 0.07)
            }
            .frame(width: width * 0.5, height: width * 0.5)
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
