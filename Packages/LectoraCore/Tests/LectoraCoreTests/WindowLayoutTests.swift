import CoreGraphics
import XCTest
@testable import LectoraCore

/// La forma de la ventana en los cuatro modos del iPhone Duo y en un iPhone (27 nov 2026): la misma
/// regla para todos, sin preguntar el aparato.
final class WindowLayoutTests: XCTestCase {
    private func window(_ width: CGFloat, _ height: CGFloat, leading: CGFloat = 0, trailing: CGFloat = 0) -> WindowLayout {
        WindowLayout.make(size: CGSize(width: width, height: height), leading: leading, trailing: trailing,
                          foldMinSide: 600, shortHeight: 500, foldWidth: 48, stripMin: 24)
    }

    func testFoldOnlyWhenBothSidesAreLarge() {
        XCTAssertNil(window(402, 874).fold, "iPhone de pie")
        XCTAssertNil(window(874, 402).fold, "iPhone acostado")
        XCTAssertNil(window(466, 678).fold, "Duo cerrado de pie")
        XCTAssertNil(window(678, 466).fold, "Duo cerrado acostado")
        let tall = window(669, 951).fold
        XCTAssertEqual(tall?.axis, .horizontal, "Duo abierto de pie: pliegue de lado a lado")
        XCTAssertEqual(tall?.position, 475.5)
        let wide = window(951, 669).fold
        XCTAssertEqual(wide?.axis, .vertical, "Duo abierto acostado: pliegue de arriba abajo")
        XCTAssertEqual(wide?.position, 475.5)
    }

    func testShortAndStrip() {
        XCTAssertFalse(window(402, 874).isShort)
        XCTAssertTrue(window(874, 402).isShort)
        XCTAssertTrue(window(678, 466).isShort)
        XCTAssertFalse(window(951, 669).isShort)
        XCTAssertEqual(window(466, 678, leading: 0, trailing: 84).strip, .trailing, "franja de la hora al costado")
        XCTAssertNil(window(874, 402, leading: 62, trailing: 62).strip, "la isla a los dos lados no es franja")
    }

    func testPagesSplitAtTheFold() {
        let open = window(951, 669)
        let pages = open.pages(of: CGRect(x: 0, y: 0, width: 951, height: 669), minPage: 280)
        XCTAssertEqual(pages?.left.width, 475.5)
        XCTAssertEqual(pages?.right.minX, 475.5)
        XCTAssertNil(open.pages(of: CGRect(x: 475.5, y: 0, width: 475.5, height: 669), minPage: 280),
                     "lo que ya está en una página no se parte")
        XCTAssertNil(window(669, 951).pages(of: CGRect(x: 0, y: 0, width: 669, height: 951), minPage: 280),
                     "el pliegue de lado a lado no parte renglones")
        XCTAssertEqual(open.widthBeforeFold(from: 24, to: 927, minPage: 280), 451.5)
        XCTAssertNil(open.widthBeforeFold(from: 500, to: 927, minPage: 280))
    }

    /// Una sola cuenta del ancho de cada página (antes copiada seis veces): la izquierda desde la orilla
    /// segura y la derecha hasta la franja; con `even`, las dos iguales, como el libro (D8-A).
    func testPageWidthsAreOneRule() {
        let open = window(951, 669, leading: 0, trailing: 84)
        XCTAssertEqual(open.page(.leading), 475.5)
        XCTAssertEqual(open.page(.trailing), 391.5)
        XCTAssertEqual(open.page(.leading, even: true), 391.5)
        XCTAssertEqual(open.page(.trailing, even: true), 391.5)
        XCTAssertEqual(open.evenInset(.leading), 84, "la franja se reserva también a la izquierda")
        XCTAssertEqual(open.evenInset(.trailing), 0)
        XCTAssertNil(window(669, 951).page(.leading), "de pie el pliegue no hace páginas lado a lado")
        XCTAssertNil(window(402, 874).page(.trailing), "un iPhone no tiene páginas")
        XCTAssertEqual(window(402, 874).evenInset(.leading), 0)
    }

    func testHalvesSplitAtTheFoldOnlyStandingOpen() {
        let standing = window(669, 951)
        let halves = standing.halves(of: CGRect(x: 0, y: 0, width: 669, height: 951), minHalf: 280)
        XCTAssertEqual(halves?.top.height, 475.5)
        XCTAssertEqual(halves?.bottom.minY, 475.5)
        XCTAssertEqual(halves?.bottom.height, 475.5)
        XCTAssertNil(standing.halves(of: CGRect(x: 0, y: 300, width: 669, height: 651), minHalf: 280),
                     "si arriba del pliegue queda poco, no se parte")
        XCTAssertNil(window(951, 669).halves(of: CGRect(x: 0, y: 0, width: 951, height: 669), minHalf: 280),
                     "acostado, el pliegue de arriba abajo da páginas, no mitades")
        XCTAssertNil(window(402, 874).halves(of: CGRect(x: 0, y: 0, width: 402, height: 874), minHalf: 280),
                     "un iPhone no tiene pliegue")
    }

    func testCoverColumnsRoundUpAndRespectHeight() {
        // Antes: tres portadas de 196 en 620 de ancho aunque el tope era 150.
        XCTAssertEqual(CoverColumns.count(width: 620, height: 0, fewest: 3, widest: 150, gap: 16, heightShare: 0.4, aspect: 2.0 / 3.0), 4)
        // Ventana baja (466 de alto): las portadas no pasan del 40 % del alto, más columnas.
        let short = CoverColumns.count(width: 600, height: 466, fewest: 3, widest: 150, gap: 16, heightShare: 0.4, aspect: 2.0 / 3.0)
        XCTAssertGreaterThanOrEqual(short, 5)
        // Un iPhone de pie sigue con tres.
        XCTAssertEqual(CoverColumns.count(width: 354, height: 874, fewest: 3, widest: 150, gap: 16, heightShare: 0.4, aspect: 2.0 / 3.0), 3)
    }

    func testReaderSpread() {
        let margin: CGFloat = 24, column: CGFloat = 280
        // Duo abierto acostado: dos páginas, márgenes iguales, lomo de dos márgenes.
        let open = ReaderSpread.make(window: window(951, 669), safeLeading: 0, safeTrailing: 0,
                                     textMargin: margin, minColumn: column, twoPages: true)
        XCTAssertEqual(open.pages, 2)
        XCTAssertEqual(open.spine, 2 * margin)
        XCTAssertEqual(open.leading, open.trailing)
        // Con la opción de una sola página, una.
        XCTAssertEqual(ReaderSpread.make(window: window(951, 669), safeLeading: 0, safeTrailing: 0,
                                         textMargin: margin, minColumn: column, twoPages: false).pages, 1)
        // Duo cerrado de pie con su franja: la columna no se angosta, cada lado el suyo.
        let closed = ReaderSpread.make(window: window(466, 678, trailing: 84), safeLeading: 0, safeTrailing: 84,
                                       textMargin: margin, minColumn: column, twoPages: true)
        XCTAssertEqual(closed.pages, 1)
        XCTAssertEqual(closed.leading, 0)
        XCTAssertEqual(closed.trailing, 84)
        // iPhone acostado con la isla: márgenes iguales (el libro centrado), una página (no hay pliegue).
        let phone = ReaderSpread.make(window: window(874, 402, leading: 62, trailing: 62), safeLeading: 62, safeTrailing: 0,
                                      textMargin: margin, minColumn: column, twoPages: true)
        XCTAssertEqual(phone.pages, 1)
        XCTAssertEqual(phone.leading, phone.trailing)
        // Continuo con pliegue: el texto en una página, la otra de margen.
        let one = ReaderSpread.make(window: window(951, 669), safeLeading: 0, safeTrailing: 0,
                                    textMargin: margin, minColumn: column, twoPages: false)
        let box = one.onePage(in: window(951, 669), textOnRight: false)
        XCTAssertEqual(box?.trailing, 475.5)
        XCTAssertNil(open.onePage(in: window(951, 669), textOnRight: false))
    }
}
