#if os(iOS)
import UIKit
import WebKit

/// Pasar de página como una hoja que da vuelta (Libros de Apple).
///
/// El WebView no sabe doblar la página, así que se fotografía: la página de
/// ahora tapa al lector, el lector pasa de página sin animación por debajo, se
/// fotografía la nueva y la hoja de arriba se dobla con la curva de UIKit.
@MainActor
final class PageCurler {
    private var busy = false

    /// `move` pasa de página sin animación y dice si de verdad se movió
    /// (al final del libro no hay a dónde).
    func turn(_ webView: WKWebView, forward: Bool, background: UIColor,
              move: @escaping (@escaping (Bool) -> Void) -> Void) {
        guard !busy else { return }
        busy = true
        webView.takeSnapshot(with: nil) { [weak self, weak webView] image, _ in
            MainActor.assumeIsolated {
                guard let self, let webView, let image else {
                    self?.busy = false
                    move { _ in }
                    return
                }
                let pages = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
                pages.isDoubleSided = false
                pages.setViewControllers([Self.page(image, background)], direction: .forward, animated: false)
                let host = Self.hostController(of: webView)
                host?.addChild(pages)
                pages.view.frame = webView.bounds
                pages.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                webView.addSubview(pages.view)
                pages.didMove(toParent: host)

                let finish = { [weak self] in
                    pages.willMove(toParent: nil)
                    pages.view.removeFromSuperview()
                    pages.removeFromParent()
                    self?.busy = false
                }
                move { moved in
                    guard moved else { finish(); return }
                    webView.takeSnapshot(with: nil) { next, _ in
                        MainActor.assumeIsolated {
                            guard let next else { finish(); return }
                            pages.setViewControllers([Self.page(next, background)],
                                                     direction: forward ? .forward : .reverse,
                                                     animated: true) { _ in finish() }
                        }
                    }
                }
            }
        }
    }

    /// Una hoja: el color del papel y la foto de la página encima (el WebView es
    /// transparente; sin el papel, la hoja que se dobla dejaría ver la de abajo).
    private static func page(_ image: UIImage, _ background: UIColor) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = background
        let imageView = UIImageView(image: image)
        imageView.frame = controller.view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleToFill
        controller.view.addSubview(imageView)
        return controller
    }

    private static func hostController(of view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }
}
#endif
