import Foundation

/// Marca de tiempo híbrida (reloj físico + contador lógico + nodo).
///
/// Ordena los cambios de todos los dispositivos de forma total y determinista,
/// aunque los relojes de los dispositivos no estén sincronizados entre sí.
public struct HLC: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    /// Milisegundos desde 1970 según el reloj del dispositivo (o el mayor visto).
    public var wallMillis: Int64
    /// Desempate cuando dos eventos caen en el mismo milisegundo.
    public var counter: UInt32
    /// Identificador del dispositivo; desempate final para que el orden sea total.
    public var node: String

    public init(wallMillis: Int64, counter: UInt32, node: String) {
        self.wallMillis = wallMillis
        self.counter = counter
        self.node = node
    }

    public static func < (lhs: HLC, rhs: HLC) -> Bool {
        if lhs.wallMillis != rhs.wallMillis { return lhs.wallMillis < rhs.wallMillis }
        if lhs.counter != rhs.counter { return lhs.counter < rhs.counter }
        return lhs.node < rhs.node
    }

    public var description: String { "\(wallMillis)-\(counter)-\(node)" }
}

/// Genera marcas HLC monótonas para un dispositivo.
public final class HybridLogicalClock: @unchecked Sendable {
    public let node: String
    private var last: HLC
    private let now: () -> Int64
    private let lock = NSLock()

    /// - Parameter now: fuente de tiempo en milisegundos (inyectable para pruebas).
    public init(node: String, now: @escaping () -> Int64 = HybridLogicalClock.systemMillis) {
        self.node = node
        self.now = now
        self.last = HLC(wallMillis: 0, counter: 0, node: node)
    }

    public static func systemMillis() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
    }

    /// Marca para un cambio local nuevo.
    public func tick() -> HLC {
        lock.lock(); defer { lock.unlock() }
        let physical = now()
        if physical > last.wallMillis {
            last = HLC(wallMillis: physical, counter: 0, node: node)
        } else {
            last = HLC(wallMillis: last.wallMillis, counter: last.counter + 1, node: node)
        }
        return last
    }

    /// Ajusta el reloj al recibir un cambio de otro dispositivo, para que
    /// los cambios locales posteriores siempre queden ordenados después.
    public func receive(_ remote: HLC) {
        lock.lock(); defer { lock.unlock() }
        let physical = now()
        let maxWall = max(physical, last.wallMillis, remote.wallMillis)
        let counter: UInt32
        if maxWall == last.wallMillis && maxWall == remote.wallMillis {
            counter = max(last.counter, remote.counter) + 1
        } else if maxWall == last.wallMillis {
            counter = last.counter + 1
        } else if maxWall == remote.wallMillis {
            counter = remote.counter + 1
        } else {
            counter = 0
        }
        last = HLC(wallMillis: maxWall, counter: counter, node: node)
    }
}
