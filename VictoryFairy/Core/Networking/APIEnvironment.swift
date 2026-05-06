import Foundation

struct APIEnvironment: Equatable {
    enum EnvironmentName: String {
        case dev
        case production
    }

    let name: EnvironmentName
    let baseURL: URL
    let fallbackBaseURL: URL?
    let timeout: TimeInterval

    var healthURL: URL {
        endpointURL(baseURL: baseURL, path: "/health", queryItems: [])
    }

    static var current: APIEnvironment {
        #if VICTORYFAIRY_PRODUCTION
        return .production(
            baseURL: configuredBaseURL(fallback: "http://victoryfairy.duckdns.org")
        )
        #else
        return .development(
            baseURL: configuredBaseURL(fallback: "http://localhost:8081")
        )
        #endif
    }

    static func development(baseURL: URL = URL(string: "http://localhost:8081")!) -> APIEnvironment {
        APIEnvironment(
            name: .dev,
            baseURL: baseURL,
            fallbackBaseURL: URL(string: "http://127.0.0.1:8081"),
            timeout: 8
        )
    }

    static func physicalDevice(macLocalIP: String, port: Int = 8081) -> APIEnvironment {
        APIEnvironment(
            name: .dev,
            baseURL: URL(string: "http://\(macLocalIP):\(port)")!,
            fallbackBaseURL: nil,
            timeout: 8
        )
    }

    static func production(baseURL: URL) -> APIEnvironment {
        APIEnvironment(
            name: .production,
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
        APIEnvironmentDebugLogger.logOnce(environment: name, baseURL: baseURL, healthURL: healthURL)
        if let fallbackBaseURL {
            APIEnvironmentDebugLogger.logOnce(
                environment: name,
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

    private static func configuredBaseURL(fallback: String) -> URL {
        let configuredValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let trimmedValue = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmedValue?.isEmpty == false ? trimmedValue : fallback
        return URL(string: urlString ?? fallback) ?? URL(string: fallback)!
    }
}

#if DEBUG
private enum APIEnvironmentDebugLogger {
    private static var logged = Set<String>()
    private static let lock = NSLock()

    static func logOnce(environment: APIEnvironment.EnvironmentName, baseURL: URL, healthURL: URL) {
        let key = "\(baseURL.absoluteString)|\(healthURL.absoluteString)"
        lock.lock()
        defer { lock.unlock() }
        guard logged.insert(key).inserted else { return }
        print("[APIEnvironment] environment=\(environment.rawValue) baseURL=\(baseURL.absoluteString)")
        print("[APIEnvironment] healthURL=\(healthURL.absoluteString)")
    }
}
#endif
