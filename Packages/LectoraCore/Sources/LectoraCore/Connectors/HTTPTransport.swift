import Foundation

/// Manda una petición y devuelve la respuesta. En la app es `URLSession`; en
/// las pruebas, una respuesta escrita a mano.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ConnectorError.unexpected("Respuesta sin HTTP") }
        return (data, http)
    }
}

/// Lo que puede salir mal al hablar con un servicio, en palabras.
public enum ConnectorError: LocalizedError, Equatable, Sendable {
    /// La llave no sirve (401/403).
    case badKey
    /// Demasiadas peticiones: hay que esperar.
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int, message: String)
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .badKey: "La llave no funciona. Revisa que la copiaste completa."
        case .rateLimited: "El servicio pidió esperar un momento. Vuelvo a intentarlo solo."
        case .server(let status, let message): "El servicio respondió \(status): \(message)"
        case .unexpected(let message): message
        }
    }

    static func check(_ response: HTTPURLResponse, _ data: Data) throws {
        switch response.statusCode {
        case 200..<300: return
        case 401, 403: throw ConnectorError.badKey
        case 429:
            let retry = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ConnectorError.rateLimited(retryAfter: retry)
        default:
            throw ConnectorError.server(status: response.statusCode,
                                        message: String(decoding: data.prefix(300), as: UTF8.self))
        }
    }
}
