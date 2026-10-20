import Foundation

/// ISBN con dígito de control verificado. Muchos EPUB traen en el campo ISBN
/// un UUID, un número interno o un ISBN mal copiado: esos no se usan para buscar
/// ni para dar un libro por idéntico.
public enum ISBN {
    /// ISBN-13 válido, o `nil`. Acepta guiones y espacios, e ISBN-10 (que se convierte).
    public static func normalized(_ text: String) -> String? {
        let digits = text.uppercased().filter { $0.isNumber || $0 == "X" }
        switch digits.count {
        case 13 where isValid13(digits) && (digits.hasPrefix("978") || digits.hasPrefix("979")):
            return digits
        case 10 where isValid10(digits):
            return to13(digits)
        default:
            return nil
        }
    }

    /// Dos ISBN son el mismo libro aunque uno sea de 10 y el otro de 13.
    public static func same(_ a: String, _ b: String) -> Bool {
        guard let left = normalized(a), let right = normalized(b) else { return false }
        return left == right
    }

    static func isValid13(_ digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard values.count == 13 else { return false }
        let sum = values.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
        return sum % 10 == 0
    }

    static func isValid10(_ digits: String) -> Bool {
        let chars = Array(digits)
        guard chars.count == 10 else { return false }
        var sum = 0
        for (index, char) in chars.enumerated() {
            let value: Int
            if char == "X", index == 9 { value = 10 } else if let digit = char.wholeNumberValue { value = digit } else { return false }
            sum += value * (10 - index)
        }
        return sum % 11 == 0
    }

    static func to13(_ isbn10: String) -> String {
        let body = "978" + isbn10.prefix(9)
        let values = body.compactMap(\.wholeNumberValue)
        let sum = values.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
        return body + String((10 - sum % 10) % 10)
    }
}
