import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case httpStatus(Int)
    case server(code: String, message: String)
    case decoding(String)
    case emptyData
    case notModifiedWithoutCache

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "서버 주소가 올바르지 않아요."
        case .requestFailed(let message):
            return "서버에 연결할 수 없어요. \(message)"
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .httpStatus(let statusCode):
            return "서버 응답 상태가 올바르지 않아요. (\(statusCode))"
        case .server(_, let message):
            return message
        case .decoding(let message):
            return "서버 데이터를 읽을 수 없어요. \(message)"
        case .emptyData:
            return "서버 데이터가 비어 있어요."
        case .notModifiedWithoutCache:
            return "서버가 새 데이터를 보내지 않았어요."
        }
    }

    var debugReason: String {
        switch self {
        case .invalidURL:
            return "invalidURL"
        case .requestFailed(let message):
            return "requestFailed(\(message))"
        case .invalidResponse:
            return "invalidResponse"
        case .httpStatus(let statusCode):
            return "httpStatus(\(statusCode))"
        case .server(let code, let message):
            return "server(\(code), \(message))"
        case .decoding(let message):
            return "decoding(\(message))"
        case .emptyData:
            return "emptyData"
        case .notModifiedWithoutCache:
            return "notModifiedWithoutCache"
        }
    }
}
