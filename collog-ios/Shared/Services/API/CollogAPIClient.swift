//
//  CollogAPIClient.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct CollogAPIClient {
    var baseURL: URL
    var accessToken: String?
    var session: URLSession = .shared

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = Date.fromCollogTimestamp(raw) else {
                throw APIError.decoding(raw)
            }
            return date
        }
        return decoder
    }()

    func send<Response: Decodable>(_ endpoint: APIEndpoint) async throws -> Response {
        let data = try await sendRaw(endpoint)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    @discardableResult
    func sendRaw(_ endpoint: APIEndpoint) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty {
            components?.queryItems = endpoint.query
        }
        guard let url = components?.url else {
            throw APIError.transport("주소를 만들 수 없어요")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        if endpoint.requiresAuth {
            guard let accessToken else { throw APIError.unauthenticated }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        return try await perform(request)
    }

    func upload(fileURL: URL, to urlString: String, contentType: String) async throws {
        guard let url = URL(string: urlString) else {
            throw APIError.transport("업로드 주소가 올바르지 않아요")
        }
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.put.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, fromFile: fileURL)
        try Self.validate(response: response, data: data)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        try Self.validate(response: response, data: data)
        return data
    }

    private static func validate(response: URLResponse, data: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard !(200..<300).contains(status) else { return }

        if status == 401 { throw APIError.unauthenticated }

        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        throw APIError.server(
            status: status,
            code: body?.code ?? "REQUEST_FAILED",
            message: body?.message ?? "요청을 처리하지 못했어요"
        )
    }
}

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

extension ISO8601DateFormatter {
    static let collog: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let collogWholeSecond: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension Date {
    static func fromCollogTimestamp(_ raw: String) -> Date? {
        let normalized = hasTimeZone(raw) ? raw : raw + "Z"
        return ISO8601DateFormatter.collog.date(from: normalized)
            ?? ISO8601DateFormatter.collogWholeSecond.date(from: normalized)
    }

    private static func hasTimeZone(_ raw: String) -> Bool {
        guard let timeStart = raw.firstIndex(of: "T") else { return false }
        let time = raw[timeStart...]
        return time.hasSuffix("Z") || time.contains("+") || time.dropFirst().contains("-")
    }
}
