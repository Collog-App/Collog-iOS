//
//  CallConnectFailure.swift
//  collog-ios
//

import Foundation
import LiveKit

/// 이용 기록 `call_connect_failed`의 코드(2026-11-24 약속).
enum CallConnectFailure: String {
    case microphonePermission = "MIC_PERMISSION"
    case network = "NETWORK"
    case token = "TOKEN"
    case server = "SERVER"
    case other = "OTHER"

    init(_ error: Error) {
        switch error {
        case APIError.transport, is URLError:
            self = .network
        case APIError.unauthenticated:
            self = .token
        case APIError.server, APIError.decoding:
            self = .server
        case let error as LiveKitError:
            self = Self.liveKit(error.type)
        default:
            self = .other
        }
    }

    /// LiveKit 접속 실패. 토큰 검증(4xx)은 `.validation`, 서버 오류·연결 문제는 `.network`로 온다.
    private static func liveKit(_ type: LiveKitErrorType) -> Self {
        switch type {
        case .network, .timedOut, .serverPingTimedOut: .network
        case .validation, .insufficientPermissions: .token
        case .serverShutdown, .joinFailure, .stateMismatch, .serviceNotFound, .duplicateIdentity: .server
        case .deviceAccessDenied: .microphonePermission
        default: .other
        }
    }
}
