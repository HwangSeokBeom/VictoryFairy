import Foundation

struct APIClient {
    private let environment: APIEnvironment
    private let deviceIDProvider: DeviceIDProvider
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        environment: APIEnvironment = .development,
        deviceIDProvider: DeviceIDProvider = DeviceIDProvider(),
        session: URLSession? = nil
    ) {
        self.environment = environment
        self.deviceIDProvider = deviceIDProvider
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], requiresDeviceID: Bool = true) async throws -> T {
        try await request(path, method: "GET", queryItems: queryItems, body: Optional<EmptyAPIData>.none, requiresDeviceID: requiresDeviceID)
    }

    func post<RequestBody: Encodable, T: Decodable>(_ path: String, body: RequestBody, requiresDeviceID: Bool = true) async throws -> T {
        try await request(path, method: "POST", body: body, requiresDeviceID: requiresDeviceID)
    }

    func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String] = [:],
        files: [MultipartFile],
        requiresDeviceID: Bool = true
    ) async throws -> T {
        do {
            return try await multipartRequest(baseURL: environment.baseURL, path: path, fields: fields, files: files, requiresDeviceID: requiresDeviceID)
        } catch {
            guard let fallbackBaseURL = environment.fallbackBaseURL else {
                throw normalize(error)
            }
            do {
                return try await multipartRequest(baseURL: fallbackBaseURL, path: path, fields: fields, files: files, requiresDeviceID: requiresDeviceID)
            } catch {
                throw normalize(error)
            }
        }
    }

    func put<RequestBody: Encodable, T: Decodable>(_ path: String, body: RequestBody, requiresDeviceID: Bool = true) async throws -> T {
        try await request(path, method: "PUT", body: body, requiresDeviceID: requiresDeviceID)
    }

    func delete<T: Decodable>(_ path: String, requiresDeviceID: Bool = true) async throws -> T {
        try await request(path, method: "DELETE", queryItems: [], body: Optional<EmptyAPIData>.none, requiresDeviceID: requiresDeviceID)
    }

    func health() async throws {
        let _: HealthDTO = try await request("/health", method: "GET", queryItems: [], body: Optional<EmptyAPIData>.none, requiresDeviceID: false)
    }

    private func request<RequestBody: Encodable, T: Decodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: RequestBody?,
        requiresDeviceID: Bool
    ) async throws -> T {
        do {
            return try await request(baseURL: environment.baseURL, path: path, method: method, queryItems: queryItems, body: body, requiresDeviceID: requiresDeviceID)
        } catch {
            if normalize(error) == .notModifiedWithoutCache {
                throw APIError.notModifiedWithoutCache
            }
            guard let fallbackBaseURL = environment.fallbackBaseURL else {
                throw normalize(error)
            }
            do {
                return try await request(baseURL: fallbackBaseURL, path: path, method: method, queryItems: queryItems, body: body, requiresDeviceID: requiresDeviceID)
            } catch {
                throw normalize(error)
            }
        }
    }

    private func request<RequestBody: Encodable, T: Decodable>(
        baseURL: URL,
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: RequestBody?,
        requiresDeviceID: Bool
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = [baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), trimmedPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: environment.timeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if requiresDeviceID {
            request.setValue(deviceIDProvider.deviceID, forHTTPHeaderField: "X-Device-ID")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("\(method) \(endpointDisplay(path)) failed reason=requestFailed(\(error.localizedDescription))")
            throw APIError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("\(method) \(endpointDisplay(path)) failed reason=invalidResponse")
            throw APIError.invalidResponse
        }
        debugLog("\(method) \(endpointDisplay(path)) status=\(httpResponse.statusCode) deviceID=\(requiresDeviceID)")

        if httpResponse.statusCode == 304 {
            debugLog("304 received, using local fallback")
            throw APIError.notModifiedWithoutCache
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if data.isEmpty {
                throw APIError.httpStatus(httpResponse.statusCode)
            }
            do {
                let responseEnvelope = try decoder.decode(APIResponse<T>.self, from: data)
                if let serverError = responseEnvelope.error {
                    throw APIError.server(code: serverError.code, message: serverError.message)
                }
            } catch let apiError as APIError {
                throw apiError
            } catch {
                throw APIError.httpStatus(httpResponse.statusCode)
            }
            throw APIError.httpStatus(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            if T.self == EmptyAPIData.self, let empty = EmptyAPIData() as? T {
                return empty
            }
            throw APIError.emptyData
        }

        do {
            let responseEnvelope = try decoder.decode(APIResponse<T>.self, from: data)
            if responseEnvelope.success, let responseData = responseEnvelope.data, (200..<300).contains(httpResponse.statusCode) {
                return responseData
            }
            if responseEnvelope.success, T.self == EmptyAPIData.self, let empty = EmptyAPIData() as? T, (200..<300).contains(httpResponse.statusCode) {
                return empty
            }
            if let serverError = responseEnvelope.error {
                throw APIError.server(code: serverError.code, message: serverError.message)
            }
            if !(200..<300).contains(httpResponse.statusCode) {
                throw APIError.httpStatus(httpResponse.statusCode)
            }
            throw APIError.emptyData
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func multipartRequest<T: Decodable>(
        baseURL: URL,
        path: String,
        fields: [String: String],
        files: [MultipartFile],
        requiresDeviceID: Bool
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = [baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), trimmedPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url, timeoutInterval: environment.timeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if requiresDeviceID {
            request.setValue(deviceIDProvider.deviceID, forHTTPHeaderField: "X-Device-ID")
        }
        request.httpBody = makeMultipartBody(fields: fields, files: files, boundary: boundary)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("POST \(endpointDisplay(path)) failed reason=requestFailed(\(error.localizedDescription))")
            throw APIError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("POST \(endpointDisplay(path)) failed reason=invalidResponse")
            throw APIError.invalidResponse
        }
        debugLog("POST \(endpointDisplay(path)) status=\(httpResponse.statusCode) multipart=true")

        guard (200..<300).contains(httpResponse.statusCode) else {
            if data.isEmpty {
                throw APIError.httpStatus(httpResponse.statusCode)
            }
            if let responseEnvelope = try? decoder.decode(APIResponse<T>.self, from: data),
               let serverError = responseEnvelope.error {
                throw APIError.server(code: serverError.code, message: serverError.message)
            }
            throw APIError.httpStatus(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw APIError.emptyData
        }

        do {
            let responseEnvelope = try decoder.decode(APIResponse<T>.self, from: data)
            if responseEnvelope.success, let responseData = responseEnvelope.data {
                return responseData
            }
            if let serverError = responseEnvelope.error {
                throw APIError.server(code: serverError.code, message: serverError.message)
            }
            throw APIError.emptyData
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func makeMultipartBody(fields: [String: String], files: [MultipartFile], boundary: String) -> Data {
        var data = Data()
        let lineBreak = "\r\n"
        for (name, value) in fields {
            data.append("--\(boundary)\(lineBreak)")
            data.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak + lineBreak)")
            data.append("\(value)\(lineBreak)")
        }
        for file in files {
            data.append("--\(boundary)\(lineBreak)")
            data.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)")
            data.append("Content-Type: \(file.mimeType)\(lineBreak + lineBreak)")
            data.append(file.data)
            data.append(lineBreak)
        }
        data.append("--\(boundary)--\(lineBreak)")
        return data
    }

    private func endpointDisplay(_ path: String) -> String {
        "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[API] \(message)")
        #endif
    }

    private func normalize(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        return .requestFailed(error.localizedDescription)
    }
}

struct MultipartFile {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
