import Foundation

struct APIEnvironment: Equatable {
    let baseURL: URL
    let fallbackBaseURL: URL?
    let timeout: TimeInterval

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
}
