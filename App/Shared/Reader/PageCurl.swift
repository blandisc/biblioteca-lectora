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
        didSet { [current, turning?.page].compactMap { $0 }.forEach { $0.view.backgroundColor = paper } }
    }

    /// Se puede doblar con el dedo (en páginas, sin selección, sin «reducir movimiento»).
    var curls = true {
        didSet { dataSource = curls ? self : nil }
    }

    init(webView: WKWebView, reader: ReaderController) {
        self.webView = webView
        self.reader = reader
        current = ReaderPage()
        super.init(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        isDoubleSided = false
        dataSource = curls ? self : nil
        delegate = self
        current.view.backgroundColor = paper
        current.embed(webView)
        setViewControllers([current], direction: .forward, animated: false)
        // Los toques los resuelve el lector (orillas para pasar, centro para los controles).
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

    private func nextPage(forward: Bool, from viewController: UIViewController) -> UIViewController? {
        guard viewController === current, turning == nil, reader?.canTurn(forward: forward) == true else { return nil }
        let page = ReaderPage()
        page.forward = forward
        page.view.backgroundColor = paper
        return page
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
        guard turning == nil, let page = pendingViewControllers.first as? ReaderPage else { return }
        coverCurrent()
        turning = (page, page.forward)
        page.embed(webView)
        webView.alpha = 0
        reader?.turnInstantly(forward: page.forward) { [weak self] _ in self?.reveal() }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        finish(completed: completed)
    }

    // MARK: Con un toque en la orilla

    func turn(forward: Bool) {
        guard turning == nil, reader?.canTurn(forward: forward) == true else { return }
        let page = ReaderPage()
        page.forward = forward
        page.view.backgroundColor = paper
        coverCurrent()
        turning = (page, forward)
        // El lector pasa de página aún dentro de la ventana (fuera de ella no pinta)
        // y ya con la página nueva se muda a la hoja de abajo y se dobla la de arriba.
        reader?.turnInstantly(forward: forward) { [weak self] moved in
            guard let self else { return }
            guard moved else { self.finish(completed: false, turnBack: false); return }
            page.embed(self.webView)
            self.setViewControllers([page], direction: forward ? .forward : .reverse, animated: true) { [weak self] done in
                self?.finish(completed: done)
            }
        }
    }

    // MARK: Piezas

    private func coverCurrent() {
        guard cover == nil, let photo = webView.snapshotView(afterScreenUpdates: false) else { return }
        photo.frame = webView.frame
        photo.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        current.view.addSubview(photo)
        cover = photo
    }

    private func reveal() {
        UIView.animate(withDuration: Theme.Reader.pageReveal) { self.webView.alpha = 1 }
    }

    private func finish(completed: Bool, turnBack: Bool = true) {
        guard let turning else { return }
        self.turning = nil
        if completed {
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

/// Una hoja: el papel y, encima, el lector cuando le toca.
final class ReaderPage: UIViewController {
    var forward = true

    func embed(_ webView: WKWebView) {
        loadViewIfNeeded()
        webView.removeFromSuperview()
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(webView, at: 0)
    }
}
#endif
