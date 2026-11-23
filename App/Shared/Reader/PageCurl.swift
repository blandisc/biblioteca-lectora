#if os(iOS)
import UIKit
import WebKit

/// Pasar de página como una hoja que da vuelta y sigue al dedo (Libros de Apple).
///
/// El lector vive dentro de una hoja de un `UIPageViewController` con la curva de
/// UIKit. Al empezar a doblar, una foto de la página tapa la hoja que se va, el
/// lector se muda a la hoja de abajo y pasa de página ahí (sin animación). Si
/// sueltas sin terminar de doblar, el lector regresa y vuelve a la página de antes.
@MainActor
final class ReaderPagesController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let webView: WKWebView
    private weak var reader: ReaderController?
    private var current: ReaderPage
    /// La hoja que se está doblando y hacia dónde.
    private var turning: (page: ReaderPage, forward: Bool)?
    /// Foto de la página que tapa la hoja que se va.
    private var cover: UIView?

    /// Color del papel: la hoja es opaca (el WebView es transparente).
    var paper: UIColor = .systemBackground {
        didSet { [current, turning?.page].compactMap { $0 }.forEach { $0.paper = paper } }
    }

    /// El lomo del libro en la orilla izquierda (en páginas; en continuo no).
    var spine = true {
        didSet { [current, turning?.page].compactMap { $0 }.forEach { $0.showsSpine = spine } }
    }

    /// Se puede doblar con el dedo (en páginas, sin selección, sin «reducir movimiento»).
    var curls = true {
        didSet { dataSource = curls ? self : nil }
    }

    init(webView: WKWebView, reader: ReaderController) {
        self.webView = webView
        self.reader = reader
        current = ReaderPage()
        super.init(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                   options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)])
        // De dos caras: el revés de la hoja es papel un poco más oscuro (con una
        // sola cara, UIKit lo pinta gris claro y en noche o negro deslumbra).
        isDoubleSided = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        dataSource = curls ? self : nil
        delegate = self
        current.paper = paper
        current.showsSpine = spine
        current.embed(webView)
        setViewControllers([current], direction: .forward, animated: false)
        // Los toques los resuelve el lector (orillas para pasar, centro para los controles).
        disableTaps()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableTaps()
    }

    /// Los toques los resuelve el lector; UIKit no debe pasar la hoja con un toque.
    private func disableTaps() {
        gestureRecognizers.filter { $0 is UITapGestureRecognizer }.forEach { $0.isEnabled = false }
    }

    // MARK: Con el dedo

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        nextPage(forward: true, from: viewController)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        nextPage(forward: false, from: viewController)
    }

    /// Con dos caras, UIKit pide primero el revés de la hoja y luego la página siguiente.
    private func nextPage(forward: Bool, from viewController: UIViewController) -> UIViewController? {
        if viewController === current {
            if let turning {
                guard turning.forward == forward else { return nil }
            } else {
                guard reader?.canTurn(forward: forward) == true else { return nil }
            }
            let reverse = back()
            reverse.forward = forward
            return reverse
        }
        guard turning == nil, let reverse = viewController as? ReaderBack, reverse.forward == forward else { return nil }
        let page = ReaderPage()
        page.forward = forward
        page.paper = paper
        page.showsSpine = spine
        return page
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
        guard turning == nil, let page = pendingViewControllers.compactMap({ $0 as? ReaderPage }).first else { return }
        coverCurrent()
        turning = (page, page.forward)
        page.embed(webView)
        webView.alpha = 0
        reader?.turnInstantly(forward: page.forward) { [weak self] _ in self?.reveal() }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        finish(completed: completed, fromDrag: true)
    }

    // MARK: Con un toque en la orilla

    func turn(forward: Bool) {
        guard turning == nil, reader?.canTurn(forward: forward) == true else { return }
        let page = ReaderPage()
        page.forward = forward
        page.paper = paper
        page.showsSpine = spine
        coverCurrent()
        turning = (page, forward)
        // El lector pasa de página aún dentro de la ventana (fuera de ella no pinta)
        // y ya con la página nueva se muda a la hoja de abajo y se dobla la de arriba.
        reader?.turnInstantly(forward: forward) { [weak self] moved in
            guard let self else { return }
            guard moved else { self.finish(completed: false, turnBack: false); return }
            if forward { self.reader?.turnedForward() }
            page.embed(self.webView)
            // Con dos caras, la animación pide la hoja nueva y el revés de la que se dobla.
            self.setViewControllers([page, self.back()], direction: forward ? .forward : .reverse, animated: true) { [weak self] done in
                self?.finish(completed: done)
            }
        }
    }

    // MARK: Piezas

    private func back() -> ReaderBack {
        let reverse = ReaderBack()
        reverse.view.backgroundColor = Self.shaded(paper)
        // Si UIKit deja el revés encima tras doblar, que no se quede con los toques.
        reverse.view.isUserInteractionEnabled = false
        return reverse
    }

    /// El papel con menos luz, para el revés de la hoja.
    private static func shaded(_ color: UIColor) -> UIColor {
        UIColor { traits in
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            let resolved = color.resolvedColor(with: traits)
            guard resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return resolved }
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * Theme.Reader.pageBack, alpha: alpha)
        }
    }

    private func coverCurrent() {
        guard cover == nil, let photo = webView.snapshotView(afterScreenUpdates: false) else { return }
        photo.frame = webView.frame
        photo.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        photo.isUserInteractionEnabled = false
        // Debajo del lomo: la sombra se queda encima de la foto y se dobla con la hoja.
        current.view.insertSubview(photo, belowSubview: current.spineShade)
        cover = photo
    }

    private func reveal() {
        UIView.animate(withDuration: Theme.Reader.pageReveal) { self.webView.alpha = 1 }
    }

    private func finish(completed: Bool, turnBack: Bool = true, fromDrag: Bool = false) {
        guard let turning else { return }
        self.turning = nil
        if completed {
            // Con el dedo, la vibración llega al asentarse la hoja (con un toque, al empezar).
            if fromDrag && turning.forward { reader?.turnedForward() }
            cover?.removeFromSuperview()
            cover = nil
            current = turning.page
            current.embed(webView)
            webView.alpha = 1
            return
        }
        // Se soltó sin doblar: el lector regresa a su hoja, debajo de la foto, y
        // vuelve a la página de antes; luego se quita la foto.
        current.view.insertSubview(webView, at: 0)
        webView.frame = current.view.bounds
        webView.alpha = 1
        let removeCover = { [weak self] in
            self?.cover?.removeFromSuperview()
            self?.cover = nil
        }
        if turnBack && webView.superview != nil {
            reader?.turnInstantly(forward: !turning.forward) { _ in removeCover() }
        } else {
            removeCover()
        }
    }
}

/// El revés de una hoja.
final class ReaderBack: UIViewController {
    var forward = true
}

/// Una hoja: el papel, encima el lector cuando le toca y, hasta arriba, el lomo.
final class ReaderPage: UIViewController {
    var forward = true
    let spineShade = SpineShade()

    var paper: UIColor = .systemBackground {
        didSet {
            loadViewIfNeeded()
            view.backgroundColor = paper
            spineShade.paper = paper
        }
    }

    var showsSpine = true {
        didSet { loadViewIfNeeded(); spineShade.isHidden = !showsSpine }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(spineShade)
    }

    /// El lomo sube hasta la orilla de la pantalla (la hoja empieza bajo la isla):
    /// si no, se cortaba en seco arriba.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.window?.safeAreaInsets.top ?? 0
        spineShade.frame = CGRect(x: 0, y: -top, width: Theme.Reader.spineWidth, height: view.bounds.height + top)
    }

    func embed(_ webView: WKWebView) {
        loadViewIfNeeded()
        webView.removeFromSuperview()
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(webView, at: 0)
    }
}

/// El lomo del libro: una sombra suave que se desvanece desde la orilla izquierda,
/// como la hoja de un libro abierto. Más marcada en papel oscuro, donde la clara no se ve.
final class SpineShade: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var paper: UIColor = .systemBackground { didSet { update() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        update()
    }

    private func update() {
        guard let gradient = layer as? CAGradientLayer else { return }
        var brightness: CGFloat = 1
        paper.resolvedColor(with: traitCollection).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        let shade = brightness < 0.5 ? Theme.Reader.spineShadeDark : Theme.Reader.spineShadeLight
        gradient.colors = [UIColor.black.withAlphaComponent(shade).cgColor, UIColor.black.withAlphaComponent(0).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
    }
}
#endif
