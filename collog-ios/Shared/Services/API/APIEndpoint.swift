//
//  APIEndpoint.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

struct APIEndpoint {
    let path: String
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var body: Encodable?
    var requiresAuth: Bool = true
}

enum APIError: LocalizedError, Equatable {
    case unauthenticated
    case server(status: Int, code: String, message: String)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated: "로그인이 필요해요"
        case let .server(_, _, message): message
        case let .transport(message): message
        case .decoding: "서버 응답을 이해하지 못했어요"
        }
    }

    var isConsentRequired: Bool {
        if case let .server(_, code, _) = self { return code == "CONSENT_REQUIRED" }
        return false
    }
}

struct APIErrorBody: Decodable {
    let code: String
    let message: String
}
