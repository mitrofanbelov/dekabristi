import Foundation

public enum APIClientError: Error, LocalizedError {
    case invalidResponse
    case inaccessibleFile(String)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .inaccessibleFile(path):
            return "The selected file could not be read from \(path)."
        case let .serverError(statusCode, message):
            return "Server error \(statusCode): \(message)"
        }
    }
}

public final class APIClient: @unchecked Sendable {
    public let baseURL: URL
    private let sessionStore: AuthSessionStore
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        sessionStore: AuthSessionStore,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.sessionStore = sessionStore
        self.urlSession = urlSession

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func health() async throws -> HealthStatus {
        try await request(path: "/health", method: "GET", responseType: HealthStatus.self)
    }

    public func register(email: String, password: String) async throws -> AuthSession {
        let session = try await request(
            path: "/auth/register",
            method: "POST",
            body: RegisterPayload(email: email, password: password),
            responseType: AuthSession.self
        )
        await sessionStore.update(session)
        return session
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        let session = try await request(
            path: "/auth/login",
            method: "POST",
            body: LoginPayload(email: email, password: password),
            responseType: AuthSession.self
        )
        await sessionStore.update(session)
        return session
    }

    public func me() async throws -> UserProfile {
        try await request(path: "/auth/me", method: "GET", responseType: UserProfile.self)
    }

    public func listItems(cursor: Date? = nil) async throws -> ItemListPage {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: ISO8601DateFormatter().string(from: $0))] } ?? []
        return try await request(path: "/items", method: "GET", queryItems: query, responseType: ItemListPage.self)
    }

    public func sync(cursor: Date?) async throws -> SyncPage {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: ISO8601DateFormatter().string(from: $0))] } ?? []
        return try await request(path: "/items/sync", method: "GET", queryItems: query, responseType: SyncPage.self)
    }

    public func createLink(url: String, title: String?) async throws -> RemoteItem {
        try await request(
            path: "/items/links",
            method: "POST",
            body: CreateLinkPayload(url: url, title: title),
            responseType: RemoteItem.self
        )
    }

    public func uploadFile(fileURL: URL, title: String?) async throws -> RemoteItem {
        let boundary = UUID().uuidString
        let payload = try makeMultipartBody(fileURL: fileURL, title: title, boundary: boundary)
        return try await request(
            path: "/items/files",
            method: "POST",
            bodyData: payload,
            contentType: "multipart/form-data; boundary=\(boundary)",
            responseType: RemoteItem.self
        )
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await request(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: bodyData,
            contentType: "application/json",
            responseType: responseType
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        bodyData: Data? = nil,
        contentType: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(
            url: baseURL.appendingPathComponent(normalizedPath),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.timeoutInterval = 60

        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if let session = await sessionStore.session() {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = serverMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIClientError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func makeMultipartBody(fileURL: URL, title: String?, boundary: String) throws -> Data {
        var data = Data()

        if let title {
            data.append("--\(boundary)\r\n")
            data.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n")
            data.append("\(title)\r\n")
        }

        let filename = fileURL.lastPathComponent
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw APIClientError.inaccessibleFile(fileURL.path)
        }
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        data.append("Content-Type: application/octet-stream\r\n\r\n")
        data.append(fileData)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")
        return data
    }

    private func serverMessage(from data: Data, statusCode: Int) -> String {
        if let extractedMessage = extractFastAPIMessage(from: data) {
            return extractedMessage
        }

        if let plainText = String(data: data, encoding: .utf8), !plainText.isEmpty {
            return plainText
        }

        if statusCode == 422 {
            return "The server rejected the submitted data as invalid."
        }

        return "Unknown error"
    }

    private func extractFastAPIMessage(from data: Data) -> String? {
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: data),
            let payload = jsonObject as? [String: Any],
            let detail = payload["detail"]
        else {
            return nil
        }

        if let detailString = detail as? String {
            return detailString
        }

        if let detailItems = detail as? [[String: Any]] {
            let messages = detailItems.compactMap { item -> String? in
                let rawMessage = item["msg"] as? String
                let locationParts = (item["loc"] as? [Any])?
                    .dropFirst()
                    .map { String(describing: $0) }
                    .joined(separator: " -> ")

                if let rawMessage, let locationParts, !locationParts.isEmpty {
                    return "\(locationParts): \(rawMessage)"
                }

                return rawMessage
            }

            if !messages.isEmpty {
                return messages.joined(separator: "\n")
            }
        }

        return nil
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let encoded = string.data(using: .utf8) {
            append(encoded)
        }
    }
}
