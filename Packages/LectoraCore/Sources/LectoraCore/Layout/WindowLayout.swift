import CoreGraphics

/// La forma de la ventana, para que cada pantalla se acomode al espacio que tiene sin preguntar
/// nunca qué aparato es (iPhone Duo, 27 nov 2026). Se calcula una vez, con el tamaño de la ventana
/// completa y lo que ocupa el sistema a cada lado, y la leen las piezas comunes (`Spread`,
/// `ReadingColumn`, `CoverGrid`, `SidePanel`, el pliego del lector).
///
/// - **Pliegue** (`fold`): una pantalla cuyos dos lados miden al menos `foldMinSide` es un libro
///   abierto (el iPhone Duo abierto, 669 × 951): el pliegue la parte a la mitad del lado largo.
///   Ningún iPhone de una pantalla llega (el más ancho mide 440). iOS no dice dónde está el
///   pliegue (`UIHingeInteraction` solo dice si está abierto), así que se deduce del tamaño.
/// - **Baja** (`isShort`): menos alto que `shortHeight` (un iPhone acostado, el Duo cerrado
///   acostado): encabezados de un renglón, el pie del lector delgado, portadas por alto.
/// - **Franja al costado** (`strip`): el sistema ocupa más de un lado que del otro (en el Duo
///   cerrado iOS pone la hora y las pestañas en una franja): lo que va pegado a esa orilla le
///   deja su aire.
public struct WindowLayout: Equatable, Sendable {
    public enum Side: Sendable { case leading, trailing }

    /// Dónde está el pliegue, en puntos de la ventana.
    public struct Fold: Equatable, Sendable {
        public enum Axis: Sendable {
            /// Corre de arriba abajo: página izquierda y página derecha (abierto y acostado).
            case vertical
            /// Corre de lado a lado: mitad de arriba y mitad de abajo (abierto y de pie).
            case horizontal
        }
        public var axis: Axis
        /// La línea del pliegue: x (vertical) o y (horizontal).
        public var position: CGFloat
        /// El lomo: lo que queda libre a los dos lados del pliegue, en total. Cada página parte
        /// en el pliegue y deja la mitad con su margen (el de pantalla, `Space.gutter`).
        public var width: CGFloat
    }

    public var size: CGSize
    public var leading: CGFloat
    public var trailing: CGFloat
    public var fold: Fold?
    public var isShort: Bool
    public var strip: Side?

    public init(size: CGSize = .zero, leading: CGFloat = 0, trailing: CGFloat = 0, fold: Fold? = nil,
                isShort: Bool = false, strip: Side? = nil) {
        self.size = size
        self.leading = leading
        self.trailing = trailing
        self.fold = fold
        self.isShort = isShort
        self.strip = strip
    }

    /// La forma de una ventana de `size` (completa, con lo del sistema) que ocupa `leading` y
    /// `trailing` a los lados. `foldMinSide`, `shortHeight`, `foldWidth` y `stripMin` vienen del tema.
    public static func make(size: CGSize, leading: CGFloat, trailing: CGFloat,
                            foldMinSide: CGFloat, shortHeight: CGFloat, foldWidth: CGFloat,
                            stripMin: CGFloat) -> WindowLayout {
        var fold: Fold?
        if min(size.width, size.height) >= foldMinSide {
            fold = size.width >= size.height
                ? Fold(axis: .vertical, position: size.width / 2, width: foldWidth)
                : Fold(axis: .horizontal, position: size.height / 2, width: foldWidth)
        }
        var strip: Side?
        if trailing - leading >= stripMin { strip = .trailing } else if leading - trailing >= stripMin { strip = .leading }
        return WindowLayout(size: size, leading: leading, trailing: trailing, fold: fold,
                            isShort: size.height > 0 && size.height < shortHeight, strip: strip)
    }

    /// El pliegue de arriba abajo, si lo hay (el único que parte un renglón).
    public var verticalFold: Fold? { fold?.axis == .vertical ? fold : nil }

    /// Las dos páginas de un rectángulo (en puntos de la ventana) que el pliegue de arriba abajo
    /// cruza, partidas en el pliegue (cada página pone su margen junto a él: así queda el lomo);
    /// `nil` si no lo cruza o si alguna quedaría más angosta que `minPage`.
    public func pages(of frame: CGRect, minPage: CGFloat) -> (left: CGRect, right: CGRect)? {
        guard let fold = verticalFold else { return nil }
        let left = CGRect(x: frame.minX, y: frame.minY, width: fold.position - frame.minX, height: frame.height)
        let right = CGRect(x: fold.position, y: frame.minY, width: frame.maxX - fold.position, height: frame.height)
        guard left.width >= minPage, right.width >= minPage else { return nil }
        return (left, right)
    }

    /// Las dos mitades de un rectángulo (en puntos de la ventana) que el pliegue de lado a lado cruza
    /// (el Duo abierto y de pie): la de arriba hasta el pliegue y la de abajo desde él; `nil` si no lo
    /// cruza o si alguna quedaría más baja que `minHalf`.
    public func halves(of frame: CGRect, minHalf: CGFloat) -> (top: CGRect, bottom: CGRect)? {
        guard let fold, fold.axis == .horizontal else { return nil }
        let top = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: fold.position - frame.minY)
        let bottom = CGRect(x: frame.minX, y: fold.position, width: frame.width, height: frame.maxY - fold.position)
        guard top.height >= minHalf, bottom.height >= minHalf else { return nil }
        return (top, bottom)
    }

    /// Si algo que va de `minX` a `maxX` (en puntos de la ventana) cruzaría el pliegue, lo más
    /// ancho que puede ser para quedarse en la página izquierda (hasta el pliegue; su margen deja
    /// el lomo). `nil` si no lo cruza o si la página quedaría más angosta que `minPage`.
    public func widthBeforeFold(from minX: CGFloat, to maxX: CGFloat, minPage: CGFloat) -> CGFloat? {
        guard let fold = verticalFold, minX < fold.position, maxX > fold.position else { return nil }
        let width = fold.position - minX
        return width >= minPage ? width : nil
    }
}

/// Las columnas de una cuadrícula de portadas (`CoverGrid`, Elegir portada): al menos `fewest` y,
/// si sobra ancho, las que hagan falta para que ninguna portada pase de `widest` de ancho ni de
/// `heightShare` del alto de la ventana (con una pantalla baja, las portadas no se comen la
/// pantalla: en el Duo cerrado acostado caben cinco en vez de tres enormes). Se redondea hacia
/// arriba: antes salían tres portadas de 196 aunque el tope era 150 (ronda 0).
public enum CoverColumns {
    public static func count(width: CGFloat, height: CGFloat, fewest: Int, widest: CGFloat,
                             gap: CGFloat, heightShare: CGFloat, aspect: CGFloat) -> Int {
        guard width > 0 else { return fewest }
        var cell = widest
        if height > 0 { cell = min(cell, height * heightShare * aspect) }
        let needed = Int(((width + gap) / (cell + gap)).rounded(.up))
        return max(fewest, needed)
    }
}

/// Cómo va el libro en la pantalla (el pliego del lector): cuántas páginas, sus márgenes a los
/// lados y el lomo. Una sola regla para el iPhone, el iPhone acostado y el Duo, sin preguntar el
/// aparato.
public struct ReaderSpread: Equatable, Sendable {
    /// Aire extra a cada lado del libro, por lo que ocupa el sistema (la isla, la franja de la hora).
    public var leading: CGFloat
    public var trailing: CGFloat
    /// Una página o dos (a cada lado del pliegue).
    public var pages: Int
    /// El espacio entre las dos páginas (o el margen entre columnas), en puntos.
    public var spine: CGFloat

    /// - `window`: la forma de la ventana; `safeLeading`/`safeTrailing`: lo que ocupa el sistema
    ///   ahora a cada lado (lo más que se ha visto, para no reacomodar el libro cuando aparece o se
    ///   va la franja de la hora).
    /// - `textMargin`: el margen del texto a cada orilla de una página.
    /// - `minColumn`: lo más angosta que puede quedar una columna de texto (unas 35 letras): si
    ///   con márgenes iguales no cabe, el margen del lado del sistema se queda solo de ese lado.
    /// - `twoPages`: si la decisión del lector pide dos páginas en un pliegue.
    public static func make(window: WindowLayout, safeLeading: CGFloat, safeTrailing: CGFloat,
                            textMargin: CGFloat, minColumn: CGFloat, twoPages: Bool) -> ReaderSpread {
        let width = window.size.width
        let reserve = max(safeLeading, safeTrailing)
        // Márgenes iguales a los dos lados (el libro centrado en la ventana, y su lomo en el pliegue)
        // si la columna sigue siendo cómoda; si no (el Duo cerrado de pie con su franja), cada lado el suyo.
        let even = width - 2 * (reserve + textMargin) >= minColumn
        let leading = even ? reserve : safeLeading
        let trailing = even ? reserve : safeTrailing
        var pages = 1
        if twoPages, window.verticalFold != nil, even {
            // Cada página: su margen afuera y medio lomo junto al pliegue (un `textMargin`).
            let page = (width - leading - trailing) / 2 - 2 * textMargin
            if page >= minColumn { pages = 2 }
        }
        return ReaderSpread(leading: leading, trailing: trailing, pages: pages, spine: 2 * textMargin)
    }

    /// Con pliegue de arriba abajo y una sola página (el modo continuo, la letra más grande): el
    /// texto va en una página y la otra es su margen. `textOnRight` la pone a la derecha.
    /// Devuelve el aire de cada lado de la caja del libro (en puntos de la ventana).
    public func onePage(in window: WindowLayout, textOnRight: Bool) -> (leading: CGFloat, trailing: CGFloat)? {
        guard pages == 1, let fold = window.verticalFold else { return nil }
        let other = window.size.width - fold.position
        return textOnRight ? (fold.position, trailing) : (leading, other)
    }
}
