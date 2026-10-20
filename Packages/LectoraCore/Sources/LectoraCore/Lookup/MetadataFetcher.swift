import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Resultado de pedir una URL a una fuente de metadatos. Se distingue «no
/// existe» de «no se pudo preguntar» para no mandar a «Por revisar» un libro
/// solo porque no había internet.
public enum FetchResult: Sendable {
    case ok(Data)
    case notFound
    case failed

    public var data: Data? {
        if case .ok(let data) = self { return data }
        return nil
    }
}

public protocol MetadataFetching: Sendable {
    func get(_ url: URL) async -> FetchResult
}

/// Peticiones reales: se identifica (Open Library lo pide), espera entre
/// peticiones al mismo servidor y reintenta si el servidor pide calma (429)
/// o falla un momento (5xx).
public struct HTTPFetcher: MetadataFetching {
    public static let userAgent = "Lectora/0.2 (https://github.com/blandisc/biblioteca-lectora)"
    private let session: URLSession
    private let retries: Int

    public init(session: URLSession = .shared, retries: Int = 2) {
        self.session = session
        self.retries = retries
    }

    public func get(_ url: URL) async -> FetchResult {
        var delay: UInt64 = 1_500_000_000
        for attempt in 0...retries {
            await RequestPacer.shared.wait(for: url.host ?? "")
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 200 { return .ok(data) }
                if status == 404 { return .notFound }
                guard status == 429 || (500...599).contains(status), attempt < retries else { return .failed }
                try? await Task.sleep(nanoseconds: delay)
                delay *= 2
            } catch {
                if (error as? URLError)?.code == .notConnectedToInternet || attempt == retries { return .failed }
                try? await Task.sleep(nanoseconds: delay)
                delay *= 2
            }
        }
        return .failed
    }
}

/// Separa las peticiones a un mismo servidor (Open Library limita a unas
/// pocas por segundo sin clave) aunque se importen cientos de libros.
actor RequestPacer {
    static let shared = RequestPacer()
    private var next: [String: Date] = [:]
    private let spacing: TimeInterval = 0.35

    func wait(for host: String) async {
        let now = Date()
        let slot = max(now, next[host] ?? now)
        next[host] = slot.addingTimeInterval(spacing)
        let pause = slot.timeIntervalSince(now)
        if pause > 0 { try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000)) }
    }
}
