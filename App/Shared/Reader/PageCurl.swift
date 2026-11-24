#if os(iOS)
import UIKit
import WebKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Pasar de página en páginas, con el estilo que elijas en «Aa» (`ReaderTurnStyle`):
/// la hoja mate que se dobla siguiendo al dedo, deslizar, fundido o al instante.
///
/// Siempre igual: una foto de la página de ahora tapa al lector, el lector pasa de
/// página debajo (sin animación) y la foto se va con el estilo elegido. Si sueltas
/// sin pasar, la foto regresa a su lugar y el lector vuelve a la página de antes.
@MainActor
final class ReaderPagesController: UIViewController, UIGestureRecognizerDelegate {
    private let webView: WKWebView
    private weak var reader: ReaderController?
    private let page = ReaderPage()
    private var turning: PageTurn?
    private var link: CADisplayLink?
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    private let curl = MatteCurl()

    /// Color del papel: la hoja es opaca (el WebView es transparente).
    var paper: UIColor = .systemBackground { didSet { page.paper = paper } }
    /// El lomo del libro en la orilla izquierda (en páginas; en continuo no).
    var spine = true { didSet { page.showsSpine = spine } }
    /// Se pasa con el dedo (en páginas, sin texto seleccionado).
    var drags = true { didSet { pan.isEnabled = drags } }
    var style: ReaderTurnStyle = .matte

    init(webView: WKWebView, reader: ReaderController) {
        self.webView = webView
        self.reader = reader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        addChild(page)
        page.view.frame = view.bounds
        page.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(page.view)
        page.didMove(toParent: self)
        page.paper = paper
        page.showsSpine = spine
        page.embed(webView)
        pan.delegate = self
        pan.isEnabled = drags
        view.addGestureRecognizer(pan)
    }

    // MARK: Con el dedo

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard gesture === pan, turning == nil else { return false }
        let velocity = pan.velocity(in: view)
        guard abs(velocity.x) > abs(velocity.y) else { return false }
        return reader?.canTurn(forward: velocity.x < 0) == true
    }

    func gestureRecognizer(_ gesture: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        let width = max(view.bounds.width, 1)
        switch gesture.state {
        case .began:
            begin(forward: gesture.velocity(in: view).x < 0,
                  fromTop: gesture.location(in: view).y < view.bounds.midY, fromDrag: true)
            // Desde donde tocaste (no desde donde el sistema reconoció el arrastre) y
            // hasta la orilla contraria: la hoja va bajo el dedo desde el primer momento.
            turning?.touchX = gesture.location(in: view).x - gesture.translation(in: view).x
            fallthrough
        case .changed:
            guard let turning, link == nil else { return }
            let x = gesture.location(in: view).x, start = turning.touchX
            let room = max(turning.forward ? start : width - start, width * Theme.Reader.turnReach)
            let distance = (x - start) * (turning.forward ? -1 : 1)
            turning.progress = min(max(distance / room, 0), 1)
            render()
        case .ended, .cancelled, .failed:
            guard let turning else { return }
            let speed = gesture.velocity(in: view).x * (turning.forward ? -1 : 1)
            let passes = gesture.state == .ended
                && (turning.progress > Theme.Reader.turnCommit || speed > Theme.Reader.turnFling)
            // La hoja sigue con la velocidad del dedo: sin frenón ni arrancón al soltar.
            let limit = Theme.Reader.turnSpeedLimit
            settle(passes, velocity: gesture.state == .ended ? min(max(speed / width, -limit), limit) : 0)
        default:
            break
        }
    }

    // MARK: Con un toque en la orilla

    func turn(forward: Bool) {
        guard turning == nil, reader?.canTurn(forward: forward) == true else { return }
        begin(forward: forward, fromTop: false, fromDrag: false)
        settle(true)
    }

    // MARK: Páginas ↔ continuo

    /// Cambia la forma del libro sin brinco: una foto de la página de ahora queda
    /// encima, el lector se acomoda debajo y, ya pintado, la foto se desvanece.
    /// `change` avisa cuando el lector ya acomodó el libro (o se cansó de esperar).
    func dissolve(_ change: @escaping (@escaping () -> Void) -> Void) {
        guard isViewLoaded, view.window != nil, turning == nil,
              !UIAccessibility.isReduceMotionEnabled,
              let cover = page.view.snapshotView(afterScreenUpdates: false) else { change {}; return }
        cover.frame = page.view.frame
        cover.isUserInteractionEnabled = false
        view.addSubview(cover)
        change { [weak self] in
            guard let self else { cover.removeFromSuperview(); return }
            self.webView.takeSnapshot(with: nil) { _, _ in
                // Relevo, como el fundido: el libro cambia de lugar al cambiar de
                // forma, así que la página de antes se va primero (queda el papel un
                // instante) y luego llega la nueva, subiendo apenas. Nunca se leen
                // dos textos corridos uno sobre otro.
                let webView = self.webView
                webView.alpha = 0
                webView.transform = CGAffineTransform(translationX: 0, y: Theme.Reader.flowRise)
                // La nueva empieza a llegar cuando la de antes ya casi se fue: un
                // traslape corto, sin corte seco y sin dos textos legibles a la vez.
                UIView.animate(withDuration: Theme.Reader.flowOut, delay: 0, options: [.curveEaseInOut]) {
                    cover.alpha = 0
                } completion: { _ in cover.removeFromSuperview() }
                UIView.animate(withDuration: Theme.Reader.flowIn, delay: Theme.Reader.flowHandoff,
                               options: [.curveEaseOut, .allowUserInteraction]) {
                    webView.alpha = 1
                    webView.transform = .identity
                }
            }
        }
    }

    // MARK: La vuelta

    private func begin(forward: Bool, fromTop: Bool, fromDrag: Bool) {
        let turn = PageTurn(forward: forward, style: style, fromTop: fromTop, fromDrag: fromDrag)
        turning = turn
        reader?.isTurning = true
        // La foto de la página de ahora tapa al lector mientras pasa de página debajo.
        if let cover = page.view.snapshotView(afterScreenUpdates: false) {
            cover.frame = page.view.frame
            cover.isUserInteractionEnabled = false
            view.addSubview(cover)
            turn.cover = cover
        }
        if style == .matte { turn.from = image(of: page.view, afterUpdates: false) }
        // Adelante la hoja se mueve desde el primer toque, sin esperar al libro: debajo
        // va papel liso y la página nueva aparece en cuanto el lector la pinta.
        // (Atrás hace falta la foto de la página anterior: ahí sí se espera.)
        if forward && style != .none {
            turn.blank = blankPage(below: turn.cover)
            arm(turn)
            turn.live = true
        }
        if forward && !fromDrag { reader?.turnedForward() }
        reader?.turnInstantly(forward: forward) { [weak self] moved in
            guard let self, self.turning === turn else { return }
            guard moved else { self.clear(); return }
            // Que WebKit pinte de verdad la página nueva antes de fotografiarla: sin
            // esto la hoja se doblaba sobre la misma página y la nueva saltaba al final.
            self.webView.takeSnapshot(with: nil) { _, _ in
                DispatchQueue.main.async { self.prepare(turn) }
            }
        }
    }

    /// Ya está la página nueva debajo: si la hoja ya se movía, se cambia el papel
    /// liso por la página de verdad; si no, se arman las piezas.
    private func prepare(_ turn: PageTurn) {
        guard turning === turn else { return }
        if turn.live {
            if turn.style == .matte { turn.to = image(of: page.view, afterUpdates: true) }
            turn.blank?.removeFromSuperview()
            turn.blank = nil
        } else {
            arm(turn)
        }
        turn.ready = true
        render()
        if let passed = turn.pendingFinish {
            finish(passed)
        } else if let passes = turn.pendingSettle, turn.animation == nil {
            settle(passes, velocity: turn.pendingVelocity)
        }
    }

    /// Las piezas del estilo (si la página nueva aún no está, la hoja mate se dobla sobre papel liso).
    private func arm(_ turn: PageTurn) {
        switch turn.style {
        case .slide where !turn.forward:
            // Atrás, la hoja anterior entra desde la izquierda encima de la de ahora,
            // que se va quedando a la sombra.
            if let incoming = page.view.snapshotView(afterScreenUpdates: true) {
                incoming.frame = page.view.frame
                incoming.isUserInteractionEnabled = false
                shade(incoming)
                turn.dim = dim(below: nil)
                view.addSubview(incoming)
                turn.incoming = incoming
            }
        case .slide:
            // Adelante, la página nueva sale de la sombra de la que se va.
            if let cover = turn.cover {
                shade(cover)
                turn.dim = dim(below: cover)
            }
        case .matte:
            if turn.live || turn.blank == nil {
                turn.to = image(of: page.view, afterUpdates: true)
            } else if let from = turn.from {
                turn.to = CIImage(color: CIColor(color: paper)).cropped(to: from.extent)
            }
            let canvas = UIImageView(frame: page.view.frame)
            canvas.isUserInteractionEnabled = false
            view.addSubview(canvas)
            turn.canvas = canvas
        case .fade, .none:
            break
        }
    }

    /// Lleva la vuelta hasta el final (pasa) o de regreso (se queda) con un resorte
    /// sin rebote que arranca con `velocity` (fracción del ancho por segundo).
    private func settle(_ passes: Bool, velocity: CGFloat = 0) {
        guard let turn = turning else { return }
        guard turn.ready || turn.live else { turn.pendingSettle = passes; turn.pendingVelocity = velocity; return }
        let target: CGFloat = passes ? 1 : 0
        guard turn.style != .none, turn.progress != target else { finish(passes); return }
        turn.animation = (to: target, velocity: velocity, time: CACurrentMediaTime())
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func step() {
        guard let turn = turning, let animation = turn.animation else { link?.invalidate(); link = nil; return }
        let now = CACurrentMediaTime()
        let stiffness = turn.style == .fade ? Theme.Reader.fadeSpring : Theme.Reader.turnSpring
        let (offset, velocity) = TurnMotion.step(offset: turn.progress - animation.to, velocity: animation.velocity,
                                                 stiffness: stiffness, dt: now - animation.time)
        turn.animation = (to: animation.to, velocity: velocity, time: now)
        // Nunca más allá del final ni de regreso: una hoja no rebota.
        turn.progress = min(max(animation.to + offset, 0), 1)
        let done = abs(turn.progress - animation.to) < Theme.Reader.turnRest
        if done { turn.progress = animation.to }
        render()
        if done {
            link?.invalidate()
            link = nil
            finish(animation.to == 1)
        }
    }

    private func render() {
        guard let turn = turning, turn.ready || turn.live else { return }
        let width = view.bounds.width
        let p = turn.progress
        switch turn.style {
        case .none:
            break
        case .fade:
            // Relevo: el texto de antes se va corriéndose hacia donde vas y, ya ido,
            // llega el nuevo desde el otro lado. Nunca se leen los dos encimados.
            let gone = TurnMotion.fadeOut(p), here = TurnMotion.fadeIn(p)
            // Con «reducir movimiento» solo se funde, sin correrse.
            let drift = UIAccessibility.isReduceMotionEnabled ? 0 : Theme.Reader.fadeDrift * (turn.forward ? -1 : 1)
            turn.cover?.alpha = 1 - gone
            turn.cover?.transform = CGAffineTransform(translationX: drift * gone, y: 0)
            webView.alpha = here
            webView.transform = CGAffineTransform(translationX: -drift * (1 - here), y: 0)
        case .slide:
            // La hoja de arriba se va de lado, opaca como papel; la de abajo sale de
            // la sombra (atrás, la de ahora se va quedando a la sombra).
            if turn.forward {
                turn.cover?.transform = CGAffineTransform(translationX: -p * width, y: 0)
                turn.dim?.alpha = Theme.Reader.slideDim * (1 - p)
            } else {
                turn.incoming?.transform = CGAffineTransform(translationX: -(1 - p) * width, y: 0)
                turn.dim?.alpha = Theme.Reader.slideDim * p
            }
        case .matte:
            guard let from = turn.from, let to = turn.to else { return }
            // Atrás, la hoja de antes se desdobla encima de la de ahora.
            let input = turn.forward ? from : to
            let target = turn.forward ? to : from
            let time = turn.forward ? p : 1 - p
            let tilt = turn.fromTop ? Theme.Reader.curlTilt : -Theme.Reader.curlTilt
            turn.canvas?.image = curl.render(input, over: target, back: Self.shaded(paper),
                                             time: time, angle: .pi + tilt)
            // La foto tapa mientras no hay dibujo; luego estorba.
            turn.cover?.isHidden = true
        }
    }

    private func finish(_ passed: Bool) {
        guard let turn = turning else { return }
        // La hoja llegó antes que la página nueva: se queda así un instante y termina al llegar.
        guard turn.ready else { turn.pendingFinish = passed; return }
        if passed {
            if turn.forward && turn.fromDrag { reader?.turnedForward() }
            clear()
            return
        }
        // Se soltó sin pasar: la página de antes está a la vista (en la foto); el
        // lector regresa debajo y luego se quitan las piezas.
        turn.cover?.isHidden = false
        turn.cover?.alpha = 1
        turn.cover?.transform = .identity
        turn.incoming?.removeFromSuperview()
        turn.canvas?.removeFromSuperview()
        turn.dim?.removeFromSuperview()
        turn.blank?.removeFromSuperview()
        reader?.turnInstantly(forward: !turn.forward) { [weak self] _ in
            DispatchQueue.main.async { self?.clear() }
        }
    }

    private func clear() {
        link?.invalidate()
        link = nil
        guard let turn = turning else { return }
        turn.cover?.removeFromSuperview()
        turn.incoming?.removeFromSuperview()
        turn.canvas?.removeFromSuperview()
        turn.dim?.removeFromSuperview()
        turn.blank?.removeFromSuperview()
        webView.alpha = 1
        webView.transform = .identity
        turning = nil
        reader?.isTurning = false
    }

    // MARK: Piezas

    /// La sombra suave de la hoja que se desliza, en su orilla derecha.
    private func shade(_ sheet: UIView) {
        sheet.layer.shadowColor = UIColor.black.cgColor
        sheet.layer.shadowOpacity = Theme.Reader.slideShadow
        sheet.layer.shadowRadius = Theme.Reader.slideShadowRadius
        sheet.layer.shadowOffset = .zero
        sheet.layer.shadowPath = UIBezierPath(rect: sheet.bounds).cgPath
    }

    /// Papel liso con su lomo, en lugar de la página nueva mientras el lector la pinta.
    private func blankPage(below sheet: UIView?) -> UIView {
        let blank = UIView(frame: page.view.frame)
        blank.backgroundColor = paper
        blank.isUserInteractionEnabled = false
        let spine = SpineShade(frame: page.spineShade.frame)
        spine.paper = paper
        spine.isHidden = !self.spine
        blank.addSubview(spine)
        if let sheet, sheet.superview === view { view.insertSubview(blank, belowSubview: sheet) } else { view.addSubview(blank) }
        return blank
    }

    /// Una sombra pareja sobre la página de abajo: justo debajo de `sheet` o, sin
    /// ella, encima de todo (lo que entre después queda sobre la sombra).
    private func dim(below sheet: UIView?) -> UIView {
        let dim = UIView(frame: page.view.frame)
        dim.backgroundColor = .black
        dim.alpha = 0
        dim.isUserInteractionEnabled = false
        if let sheet, sheet.superview === view { view.insertSubview(dim, belowSubview: sheet) } else { view.addSubview(dim) }
        return dim
    }

    private func image(of source: UIView, afterUpdates: Bool) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(view.window?.screen.scale ?? Theme.Reader.curlScale, Theme.Reader.curlScale)
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: source.bounds, format: format).image { _ in
            source.drawHierarchy(in: source.bounds, afterScreenUpdates: afterUpdates)
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }

    /// El papel con menos luz, para el revés de la hoja.
    private static func shaded(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return color }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * Theme.Reader.pageBack, alpha: alpha)
    }
}

/// Una vuelta de hoja en curso.
@MainActor
private final class PageTurn {
    let forward: Bool
    let style: ReaderTurnStyle
    let fromTop: Bool
    let fromDrag: Bool
    /// De 0 (la página de antes) a 1 (la nueva, del todo).
    var progress: CGFloat = 0
    /// Ya está la página nueva debajo y las piezas armadas.
    var ready = false
    var pendingSettle: Bool?
    /// Adelante, la hoja ya se mueve aunque la página nueva no esté (`blank` la suple).
    var live = false
    var blank: UIView?
    var pendingFinish: Bool?
    /// Dónde tocó el dedo al empezar a arrastrar.
    var touchX: CGFloat = 0
    var pendingVelocity: CGFloat = 0
    /// El resorte en curso: hacia dónde va, su velocidad y la hora del último cuadro.
    var animation: (to: CGFloat, velocity: CGFloat, time: CFTimeInterval)?
    /// La foto de la página de antes.
    var cover: UIView?
    /// Deslizar atrás: la foto de la página que entra.
    var incoming: UIView?
    /// Deslizar: la sombra sobre la página de abajo.
    var dim: UIView?
    /// Hoja mate: las dos páginas y el dibujo de la hoja doblada.
    var from: CIImage?
    var to: CIImage?
    var canvas: UIImageView?

    init(forward: Bool, style: ReaderTurnStyle, fromTop: Bool, fromDrag: Bool) {
        self.forward = forward
        self.style = style
        self.fromTop = fromTop
        self.fromDrag = fromDrag
    }
}

/// La hoja mate: Core Image dobla la foto de la página sobre la siguiente. La hoja
/// sale de `pageCurlTransition` con el revés de papel liso (apenas se transparenta
/// el texto) y sin luz; la sombra que deja sobre la página de abajo, de
/// `pageCurlWithShadowTransition`, cuyo revés sí brilla: una máscara con la forma de
/// la hoja toma la hoja de la primera y lo demás de la segunda.
@MainActor
private final class MatteCurl {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let sheet = CIFilter.pageCurlTransition()
    private let shadow = CIFilter.pageCurlWithShadowTransition()
    private let blend = CIFilter.blendWithAlphaMask()

    func render(_ input: CIImage, over target: CIImage, back paper: UIColor, time: CGFloat, angle: Double) -> UIImage? {
        let extent = input.extent
        let clear = CIImage(color: .clear).cropped(to: extent)
        let solid = CIImage(color: .white).cropped(to: extent)
        // El revés: papel más oscuro con el texto de la hoja en espejo, como a
        // contraluz: se lee que hay letra detrás, apenas suave (la tinta atraviesa
        // el papel y se abre un poco), sin competir con la página de abajo. La foto
        // va tal cual: el filtro ya la voltea al doblarla (volteada aquí también, la
        // letra salía al derecho, imposible en papel de verdad).
        let mirrored = input
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Theme.Reader.curlShowThroughBlur)
            .cropped(to: extent)
            // Colores premultiplicados: se atenúan los cuatro canales, no solo el alfa.
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: Theme.Reader.curlShowThrough, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: Theme.Reader.curlShowThrough, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: Theme.Reader.curlShowThrough, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: Theme.Reader.curlShowThrough),
            ])
        // El revés sin recortar: con la esquina inclinada, el doblez toma papel de
        // fuera del cuadro; recortado salía una cuña negra.
        let back = mirrored.composited(over: CIImage(color: CIColor(color: paper)))
        let radius = Float(extent.width * Theme.Reader.curlRadius)

        func curled(_ front: CIImage, _ below: CIImage, _ reverse: CIImage) -> CIImage? {
            sheet.inputImage = front
            sheet.targetImage = below
            sheet.backsideImage = reverse
            sheet.shadingImage = clear
            sheet.extent = extent
            sheet.time = Float(time)
            sheet.angle = Float(angle)
            sheet.radius = radius
            return sheet.outputImage?.cropped(to: extent)
        }
        // La máscara crece un poco: en su orilla suavizada se colaba el revés brillante
        // de la otra versión y dibujaba una línea blanca en el filo de la hoja.
        guard let matte = curled(input, target, back),
              let mask = curled(solid, clear, CIImage(color: .white))?
                .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: Theme.Reader.curlMaskGrow])
                .cropped(to: extent) else { return nil }

        shadow.inputImage = input
        shadow.targetImage = target
        shadow.backsideImage = back
        shadow.extent = extent
        shadow.shadowExtent = extent
        shadow.time = Float(time)
        shadow.angle = Float(angle)
        shadow.radius = radius
        shadow.shadowAmount = Theme.Reader.curlShadow
        shadow.shadowSize = Theme.Reader.curlShadow
        blend.inputImage = matte
        blend.backgroundImage = shadow.outputImage?.cropped(to: extent)
        blend.maskImage = mask
        guard let output = blend.outputImage?.cropped(to: extent),
              let image = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// Una hoja: el papel, encima el lector y, hasta arriba, el lomo.
final class ReaderPage: UIViewController {
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
