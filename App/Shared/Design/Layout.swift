import LectoraCore
import SwiftUI

// Las piezas que acomodan cada pantalla al espacio que tiene (iPhone Duo, 27 nov 2026). Ninguna
// pregunta qué aparato es: leen la forma de la ventana (`WindowLayout`, del paquete) y su propio
// lugar en ella. Con ellas la misma pantalla sirve en un iPhone de pie (no cambia nada), un iPhone
// acostado y el Duo cerrado o abierto. Ver «iPhone Duo» en docs/sistema-diseno.md.

// MARK: - La forma de la ventana

extension EnvironmentValues {
    /// La forma de la ventana: pliegue, si es baja, franja al costado. La pone `.measuresWindow()`
    /// en la raíz de lo que ocupa toda la pantalla (las pestañas, el libro, la bienvenida).
    @Entry var windowLayout = WindowLayout()
    /// Dentro de un `SidePanel`: lo que lo cierra (las hojas lo usan por `SheetDismiss`).
    @Entry var closePanel: PanelClose? = nil
}

/// Lo que cierra un `SidePanel`. Dos son iguales siempre: el panel solo cambia de visible a oculto,
/// no de cierre, y así el entorno no rehace a sus hijos en cada vuelta.
struct PanelClose: Equatable {
    let action: () -> Void
    func callAsFunction() { action() }
    static func == (_: PanelClose, _: PanelClose) -> Bool { true }
}

extension View {
    /// Mide la ventana completa (con lo que ocupa el sistema) y la deja en el entorno.
    /// Va en la raíz de lo que ocupa toda la pantalla. En la Mac no hace nada: ahí manda la ventana.
    func measuresWindow() -> some View { modifier(WindowReader()) }
}

private struct WindowReader: ViewModifier {
    @State private var layout = WindowLayout()
    @State private var host = PanelHost()

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .environment(\.panelHost, host)
            .overlay { PanelHostLayer(host: host).environment(\.windowLayout, layout) }
            .environment(\.windowLayout, layout)
            .onGeometryChange(for: WindowLayout.self) { proxy in
                let insets = proxy.safeAreaInsets
                return WindowLayout.make(
                    size: CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                                 height: proxy.size.height + insets.top + insets.bottom),
                    leading: insets.leading, trailing: insets.trailing,
                    foldMinSide: Theme.Window.foldMinSide, shortHeight: Theme.Window.shortHeight,
                    foldWidth: Theme.Space.fold, stripMin: Theme.Window.stripMin)
            } action: { layout = $0 }
        #else
        content
        #endif
    }
}

// MARK: - Spread: el pliego

/// Una pantalla en dos partes: lo principal (`leading`) y su acompañante (`trailing`). La pieza
/// decide sola cómo van:
/// - **a cada lado del pliegue** si el pliegue de arriba abajo la cruza (el Duo abierto y acostado):
///   cada parte en su página, con su propio desplazamiento, y nada sobre el lomo;
/// - **lado a lado** en una ventana baja (un iPhone acostado, el Duo cerrado acostado): la primera
///   con `Window.sideBySideShare` del ancho; con la letra más grande, una bajo otra;
/// - **una bajo otra**, en un solo desplazamiento, en todo lo demás: el iPhone de pie no cambia.
/// Mesa, ficha, Diario y bienvenida la usan; lista | detalle es `FoldSplit`.
struct Spread<Leading: View, Trailing: View>: View {
    /// Entre las dos partes cuando van una bajo otra.
    var spacing: CGFloat = Theme.Space.xxl
    /// El renglón cómodo (`ReadingColumn`) cuando van una bajo otra; `false` donde mandan las portadas.
    var measured = true
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.windowLayout) private var window
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var frame: CGRect = .zero

    private enum Arrangement: Equatable {
        case stacked
        case pages(left: CGFloat)
        case sideBySide(first: CGFloat)
    }

    private var arrangement: Arrangement {
        #if os(iOS)
        if let pages = window.pages(of: frame, minPage: Theme.Window.minPage) {
            return .pages(left: pages.left.width)
        }
        if window.isShort, !typeSize.isAccessibilitySize, frame.width >= 2 * Theme.Window.minPage {
            return .sideBySide(first: (frame.width * Theme.Window.sideBySideShare).rounded())
        }
        #endif
        return .stacked
    }

    var body: some View {
        Group {
            switch arrangement {
            case .stacked:
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing) {
                        VStack(alignment: .leading, spacing: 0) { leading }
                        VStack(alignment: .leading, spacing: 0) { trailing }
                    }
                    .screenContent(wide: !measured)
                }
            case .pages(let left):
                HStack(alignment: .top, spacing: 0) {
                    page { leading }.frame(width: left)
                    page { trailing }.frame(maxWidth: .infinity)
                }
            case .sideBySide(let first):
                HStack(alignment: .top, spacing: 0) {
                    page { leading }.frame(width: first)
                    page { trailing }.frame(maxWidth: .infinity)
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }

    /// Una página: su desplazamiento, sus márgenes y, adentro, el renglón cómodo.
    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content() }
                .screenContent(wide: true)
        }
    }
}

// MARK: - ReadingColumn: el renglón cómodo

/// Lo más ancho que crece un texto (con su margen): unas 68 letras del texto normal (`Size.readingLine`),
/// que crecen con el tamaño de texto de iOS, centrado. Si así cruzaría el pliegue (el Duo abierto y
/// acostado), se queda en la página izquierda. Ningún iPhone de pie llega a la medida; en la Mac no
/// cambia nada (ahí la ventana ya mide lo suyo).
struct ReadingColumn: ViewModifier {
    /// `false`: todo el ancho (las portadas de Mesa y Biblioteca, cada página de un pliego).
    var active = true
    @ScaledMetric(relativeTo: .body) private var line = Theme.Size.readingLine
    @Environment(\.windowLayout) private var window
    @State private var span: ClosedRange<CGFloat> = 0...0

    init(active: Bool = true) { self.active = active }

    func body(content: Content) -> some View {
        #if os(iOS)
        if active { column(content) } else { content }
        #else
        content
        #endif
    }

    @ViewBuilder
    private func column(_ content: Content) -> some View {
        let measure = line + 2 * Theme.Space.gutter
        let beforeFold = window.widthBeforeFold(from: span.lowerBound, to: span.upperBound, minPage: Theme.Window.minPage)
        content
            .frame(maxWidth: min(measure, beforeFold ?? .infinity))
            .frame(maxWidth: .infinity, alignment: beforeFold == nil ? .center : .leading)
            .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                let frame = proxy.frame(in: .global)
                return frame.minX...max(frame.minX, frame.maxX)
            } action: { span = $0 }
    }
}

extension View {
    /// El renglón cómodo (ver `ReadingColumn`).
    func readingColumn() -> some View { modifier(ReadingColumn()) }
}

// MARK: - SidePanel: una hoja en una página

/// Lo que en un iPhone es una hoja (Aa, Índice, Resumen, Editar datos, Ajustes…), con el Duo abierto
/// y acostado se abre en una página: si lo que la abre ocupa las dos páginas, en la de `side`, con la
/// otra a la vista (atenuada; tocarla cierra); si ocupa una sola, en esa misma. Nunca encima del
/// pliegue, y el libro sigue vivo al lado mientras cambias la letra o saltas entre resultados.
/// En cualquier otra ventana, la hoja de siempre. Lo de adentro se cierra con `SheetDismiss`.
private struct SidePanelModifier<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let side: WindowLayout.Side
    /// Para lo que como hoja se cierra deslizando y no trae botón («Aa»): su ✕ en el panel.
    var closeLabel: String? = nil
    @ViewBuilder let panel: () -> Panel
    @Environment(\.windowLayout) private var window
    @Environment(\.panelHost) private var host
    /// Empujada (la ficha en lista | detalle): ahí una pila dentro de la pila hacía que iOS regresara
    /// a la lista al abrir el panel (ronda 1), así que el panel sube a la raíz (`PanelHost`).
    @Environment(\.isPresented) private var pushed
    @State private var frame: CGRect = .zero
    @State private var lifted = false

    private var inPage: Bool {
        #if os(iOS)
        window.verticalFold != nil && !Duo.toolsAsSheets
        #else
        false
        #endif
    }

    private var lifts: Bool { pushed && host != nil }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { isPresented && !inPage }, set: { isPresented = $0 })) {
                panel().duoBars()
            }
            .overlay {
                if isPresented && inPage && !lifts {
                    PanelPage(frame: frame, side: side, closeLabel: closeLabel, close: close, content: panel)
                        .transition(.opacity)
                }
            }
            .animation(Theme.Motion.sheet, value: isPresented && inPage)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: isPresented && inPage && lifts, initial: true) { _, show in
                guard let host else { return }
                if show {
                    lifted = true
                    host.show(PanelHost.Shown(frame: frame, side: side, closeLabel: closeLabel, close: close,
                                              content: AnyView(panel())))
                } else if lifted {
                    lifted = false
                    host.shown = nil
                }
            }
            // Abierto antes de medirse (las capturas lo abren al aparecer): sigue a su presentador.
            .onChange(of: frame) { _, frame in if lifted { host?.shown?.frame = frame } }
            .onDisappear { if lifted { lifted = false; host?.shown = nil } }
    }

    private func close() { isPresented = false }
}

/// Lo que un `SidePanel` empujado sube a la raíz: lo pinta `.measuresWindow()` encima de todo, en
/// el mismo lugar de la ventana que tendría el panel.
@Observable
final class PanelHost {
    struct Shown {
        var frame: CGRect
        var side: WindowLayout.Side
        var closeLabel: String?
        var close: () -> Void
        var content: AnyView
    }

    var shown: Shown?

    func show(_ panel: Shown) { shown = panel }
}

extension EnvironmentValues {
    /// Dónde sube un `SidePanel` empujado (ver `PanelHost`).
    @Entry var panelHost: PanelHost? = nil
}

/// La página del panel y, si lo que lo abrió ocupa las dos, la otra atenuada (tocarla cierra).
private struct PanelPage<Panel: View>: View {
    let frame: CGRect
    let side: WindowLayout.Side
    let closeLabel: String?
    let close: () -> Void
    @ViewBuilder let content: () -> Panel
    @Environment(\.windowLayout) private var window

    var body: some View {
        let pages = window.pages(of: frame, minPage: Theme.Window.minPage)
        HStack(spacing: 0) {
            if let pages {
                if side == .trailing { shade.frame(width: pages.left.width) }
                sheet
                if side == .leading { shade.frame(width: pages.right.width) }
            } else {
                sheet
            }
        }
    }

    private var shade: some View {
        Theme.ink.opacity(Theme.Emphasis.panelShade)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
            .accessibilityLabel("Cerrar el panel")
            .accessibilityAddTraits(.isButton)
    }

    private var sheet: some View {
        content()
            .environment(\.closePanel, PanelClose(action: close))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper.ignoresSafeArea())
            // Su ✕ arriba, en su propio renglón: encima del contenido tapaba la segunda letra de «Aa».
            .safeAreaInset(edge: .top, spacing: 0) {
                if let closeLabel {
                    CloseButton(label: closeLabel, style: .glass, action: close)
                        .padding(Theme.Reader.chromeInset)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
    }
}

/// Pinta encima de todo el panel que subió un `SidePanel` empujado, en su lugar de la ventana.
private struct PanelHostLayer: View {
    let host: PanelHost

    var body: some View {
        GeometryReader { proxy in
            if let shown = host.shown {
                let origin = proxy.frame(in: .global).origin
                PanelPage(frame: shown.frame, side: shown.side, closeLabel: shown.closeLabel,
                          close: shown.close) { shown.content }
                    .frame(width: shown.frame.width, height: shown.frame.height)
                    .offset(x: shown.frame.minX - origin.x, y: shown.frame.minY - origin.y)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(Theme.Motion.sheet, value: host.shown != nil)
    }
}

/// `SidePanel` con un elemento (como `.sheet(item:)`).
private struct SidePanelItem<Item: Identifiable, Panel: View>: ViewModifier {
    @Binding var item: Item?
    let side: WindowLayout.Side
    @ViewBuilder let panel: (Item) -> Panel
    @State private var shown: Item?

    func body(content: Content) -> some View {
        content.modifier(SidePanelModifier(isPresented: Binding(get: { item != nil }, set: { if !$0 { item = nil } }),
                                           side: side, closeLabel: nil) {
            if let current = item ?? shown { panel(current) }
        })
        // Lo último que se enseñó, mientras el panel se va.
        .onChange(of: item?.id) { _, _ in if let item { shown = item } }
    }
}

extension View {
    /// Una hoja que, con el Duo abierto y acostado, se abre en una página (ver `SidePanelModifier`).
    func sidePanel(isPresented: Binding<Bool>, side: WindowLayout.Side = .trailing, closeLabel: String? = nil,
                   @ViewBuilder content: @escaping () -> some View) -> some View {
        modifier(SidePanelModifier(isPresented: isPresented, side: side, closeLabel: closeLabel, panel: content))
    }

    func sidePanel<Item: Identifiable>(item: Binding<Item?>, side: WindowLayout.Side = .trailing,
                                       @ViewBuilder content: @escaping (Item) -> some View) -> some View {
        modifier(SidePanelItem(item: item, side: side, panel: content))
    }
}

/// Cierra lo que se abrió: la hoja (`dismiss`) o el panel de una página (`SidePanel`). Lo usan las
/// hojas que pueden abrirse como panel, en vez de `@Environment(\.dismiss)`.
struct SheetDismiss: DynamicProperty {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.closePanel) private var closePanel

    func callAsFunction() {
        if let closePanel { closePanel() } else { dismiss() }
    }
}

// MARK: - FoldSplit: lista | detalle

/// La raíz de una pestaña. En un iPhone es una pila de pantallas como siempre (tocar empuja la
/// siguiente). Con el Duo abierto y acostado es un pliego: la lista en la página izquierda y lo que
/// tocas (la ficha, la nota, el resultado) en la derecha, sin ir y volver; `placeholder` dice qué
/// hay en la derecha mientras no tocas nada. Es `NavigationSplitView`: en una ventana sin pliegue
/// se pliega sola a una pila, el mismo código para los dos.
struct FoldSplit<Root: View, Placeholder: View>: View {
    /// Lo empujado: en un iPhone, encima de la lista; en el pliego, en la página derecha.
    @Binding var path: NavigationPath
    @ViewBuilder var root: Root
    @ViewBuilder var placeholder: Placeholder
    @Environment(\.windowLayout) private var window

    private var split: Bool {
        #if os(iOS)
        window.verticalFold != nil && !Duo.onePane
        #else
        false
        #endif
    }

    var body: some View {
        if split, let fold = window.verticalFold {
            // La lista llega justo al pliegue: con un ancho «ideal» iOS la dejaba en un tercio y la
            // página derecha cruzaba el pliegue (ronda 1); con mínimo y máximo iguales no la mueve.
            let sidebar = fold.position - window.leading
            NavigationSplitView(columnVisibility: .constant(.all)) {
                root
                    .navigationSplitViewColumnWidth(min: sidebar, ideal: sidebar, max: sidebar)
                    #if os(iOS)
                    .toolbar(removing: .sidebarToggle)
                    // iOS no deja la lista pasar de un tercio aunque se le pida (ronda 1: la ficha
                    // cruzaba el pliegue): el ancho se fija también en la columna de UIKit.
                    .background(PrimaryColumnWidth(width: sidebar))
                    #endif
            } detail: {
                NavigationStack(path: $path) { placeholder.screen() }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $path) { root }
        }
    }
}

#if os(iOS)
/// Fija el ancho de la lista de un `NavigationSplitView` en su `UISplitViewController`: SwiftUI pasa
/// el ancho pedido, pero UIKit lo topa en un tercio de la ventana.
private struct PrimaryColumnWidth: UIViewControllerRepresentable {
    let width: CGFloat

    func makeUIViewController(context: Context) -> Probe { Probe() }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.width = width
        probe.apply()
    }

    final class Probe: UIViewController {
        var width: CGFloat = 0

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        func apply() {
            guard width > 0, let split = splitViewController else { return }
            if split.maximumPrimaryColumnWidth != width { split.maximumPrimaryColumnWidth = width }
            if split.minimumPrimaryColumnWidth != width { split.minimumPrimaryColumnWidth = width }
            if split.preferredPrimaryColumnWidth != width { split.preferredPrimaryColumnWidth = width }
        }
    }
}
#endif

/// Lo que dice la página derecha de un pliego mientras no tocas nada a la izquierda.
struct FoldPlaceholder: View {
    let title: String
    let message: String

    var body: some View {
        EmptyState(title: title, message: message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gutter()
    }
}
