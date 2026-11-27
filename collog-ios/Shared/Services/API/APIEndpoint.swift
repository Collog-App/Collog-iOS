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
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIEndpoint {
    let path: String
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var body: Encodable?
    var requiresAuth: Bool = true
    var timeoutInterval: TimeInterval = 60
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

    /// 403: 그 가족이나 기록에 접근할 권한이 없다.
    var isForbidden: Bool {
        if case let .server(status, _, _) = self { return status == 403 }
        return false
    }

    /// 402 `PREMIUM_REQUIRED`: 결제가 켜져 있고 보는 사람의 가족이 프리미엄이 아니다(리포트).
    /// 403(가족이 공유를 껐다)과 섞지 않는다.
    var isPremiumRequired: Bool {
        if case let .server(status, _, _) = self { return status == 402 }
        return false
    }

    /// 404: 찾는 것이 이미 없다.
    var isNotFound: Bool {
        if case let .server(status, _, _) = self { return status == 404 }
        return false
    }

    /// 요청이 403 으로 막혔는지, 열렸다면 그 결과까지. 다른 실패(연결·서버 오류)로는 알 수 없어 nil.
    static func accessCheck<Value>(
        _ request: () async throws -> Value
    ) async -> (denied: Bool, value: Value?)? {
        do {
            return (false, try await request())
        } catch let error as APIError where error.isForbidden {
            return (true, nil)
        } catch {
            return nil
        }
    }
}

struct APIErrorBody: Decodable {
    let code: String
    let message: String
}
