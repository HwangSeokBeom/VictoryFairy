import Foundation

struct APIEnvironment: Equatable {
    let baseURL: URL
    let fallbackBaseURL: URL?
    let timeout: TimeInterval

    var healthURL: URL {
        endpointURL(baseURL: baseURL, path: "/health", queryItems: [])
    }

    static let development = APIEnvironment(
        baseURL: URL(string: "http://localhost:8081")!,
        fallbackBaseURL: URL(string: "http://127.0.0.1:8081"),
        timeout: 8
    )

    static func physicalDevice(macLocalIP: String, port: Int = 8081) -> APIEnvironment {
        APIEnvironment(
            baseURL: URL(string: "http://\(macLocalIP):\(port)")!,
            fallbackBaseURL: nil,
            timeout: 8
        )
    }

    static func production(baseURL: URL) -> APIEnvironment {
        APIEnvironment(
            baseURL: baseURL,
            fallbackBaseURL: nil,
            timeout: 8
        )
    }

    func endpointURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let joinedPath = normalizedPath(basePath: baseURL.path, endpointPath: path)
        components?.path = joinedPath
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url ?? baseURL
    }

    func logDebugConfiguration() {
        #if DEBUG
        APIEnvironmentDebugLogger.logOnce(baseURL: baseURL, healthURL: healthURL)
        if let fallbackBaseURL {
            APIEnvironmentDebugLogger.logOnce(
                baseURL: fallbackBaseURL,
                healthURL: endpointURL(baseURL: fallbackBaseURL, path: "/health", queryItems: [])
            )
        }
        #endif
    }

    private func normalizedPath(basePath: String, endpointPath: String) -> String {
        let baseSegments = basePath.split(separator: "/").map(String.init)
        var endpointSegments = endpointPath.split(separator: "/").map(String.init)

        let maxOverlap = min(baseSegments.count, endpointSegments.count)
        if maxOverlap > 0 {
            for overlap in stride(from: maxOverlap, through: 1, by: -1) {
                if Array(baseSegments.suffix(overlap)) == Array(endpointSegments.prefix(overlap)) {
                    endpointSegments.removeFirst(overlap)
                    break
                }
            }
        }

        let path = (baseSegments + endpointSegments).joined(separator: "/")
        return "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

#if DEBUG
private enum APIEnvironmentDebugLogger {
    private static var logged = Set<String>()
    private static let lock = NSLock()

    static func logOnce(baseURL: URL, healthURL: URL) {
        let key = "\(baseURL.absoluteString)|\(healthURL.absoluteString)"
        lock.lock()
        defer { lock.unlock() }
        guard logged.insert(key).inserted else { return }
        print("[APIEnvironment] baseURL=\(baseURL.absoluteString)")
        print("[APIEnvironment] healthURL=\(healthURL.absoluteString)")
    }
}
#endif
