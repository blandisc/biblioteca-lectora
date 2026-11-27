import Foundation

extension String {
    /// El texto entre los marcadores de aislamiento de Unicode (U+2068 … U+2069): dentro va en su
    /// dirección y no revuelve lo de alrededor. Un título en hebreo o en árabe junto a cifras
    /// («שלום עליכם · de 31 % a 36 %») se leía «% de 31 % a 36 · שלום עליכם» (auditoría 8). Todo
    /// nombre que pones tú (título, autor, serie) va así cuando se junta con otras palabras o cifras.
    public var isolated: String {
        "\u{2068}\(self)\u{2069}"
    }
}
