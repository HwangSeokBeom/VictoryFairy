import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIServerError?
}

struct EmptyAPIData: Codable {}

struct APIServerError: Decodable, Equatable {
    let code: String
    let message: String
}

struct HealthDTO: Decodable {
    let status: String
    let service: String?
}
