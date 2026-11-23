//
//  APIModels.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct APIUser: Codable, Identifiable, Hashable {
    let id: String
    let role: String
    let name: String
    let phone: String?
    var appleUserId: String?
    var familyId: String?
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: APIUser
}

struct AppleLoginChallenge: Decodable {
    let challengeId: String
    let nonce: String
    let expiresIn: Int
}

struct AppleLoginBody: Encodable {
    let identityToken: String
    let challengeId: String
    let role: String
    let name: String?
}

struct AppleDeletionBody: Encodable {
    let identityToken: String
    let challengeId: String
    let authorizationCode: String
}

struct RefreshTokenBody: Encodable {
    let refreshToken: String
}

struct AccountRoleBody: Encodable {
    let role: String
}

struct InvitationAccepted: Decodable {
    let familyId: String
    let memberId: String
    let status: String
}

struct CallStatus: Decodable {
    let state: String
    let endedAt: Date?
    let recordingEnabled: Bool?
    var recordingDisabledMessage: String? = nil

    var hasEnded: Bool {
        endedAt != nil || ["ENDED", "PROCESSING", "ANALYZED", "ANALYSIS_EXCLUDED", "ANALYSIS_FAILED"].contains(state)
    }
}

struct FamilyMember: Decodable, Identifiable, Hashable {
    let memberId: String
    let userId: String?
    let name: String
    let relation: String
    let status: String

    var id: String { memberId }
    let role: String?
    let invitation: FamilyInvitation?
    /// 내가 이 구성원(또는 대기 중 초대)을 지울 수 있는지. 서버가 보내지 않으면 nil.
    var canRemove: Bool? = nil
    var isCallable: Bool { userId != nil }

    var relationTitle: String {
        FamilyRelation.title(relation) ?? name
    }
}

struct FamilyInvitation: Decodable, Hashable, Identifiable {
    let invitationId: String
    let code: String
    let shareText: String
    let expiresAt: Date
    let status: String

    var id: String { invitationId }
    var isExpired: Bool { status == "EXPIRED" || expiresAt <= Date() }
}

struct FamilyMembersResponse: Decodable {
    let members: [FamilyMember]
    let canInvite: Bool?
}

struct FamilySummary: Decodable, Identifiable, Hashable {
    let familyId: String
    let name: String

    var id: String { familyId }
}

struct FamiliesResponse: Decodable {
    let families: [FamilySummary]
}

struct FamilyCreated: Decodable {
    let familyId: String
}

struct APIQuestion: Decodable, Identifiable, Hashable {
    let questionId: String
    let text: String
    let conditionCode: String?
    let ttsAssetUrl: String?
    let durationMs: Int?
    let ttsMode: String

    var id: String { questionId }
    var usesRemoteAudio: Bool { ttsMode == "REMOTE_ASSET" && ttsAssetUrl != nil }
}

struct DailyQuestionsResponse: Decodable {
    let source: String
    let questions: [APIQuestion]
}

struct QuestionTtsToken: Decodable {
    let token: String
    let voiceId: String
    let modelId: String
    let outputFormat: String
}

struct AudioConstraints: Decodable, Hashable {
    let echoCancellation: Bool
    let noiseSuppression: Bool
    let autoGainControl: Bool
    let dtx: Bool
    let audioBitrate: Int
    let rawCaptureSampleRate: Int
}

struct CallCreated: Decodable {
    let callId: String
    let callerId: String?
    let calleeId: String?
    let rawCaptureRequired: Bool?
    let livekitUrl: String
    let roomName: String
    let accessToken: String
    let recordingEnabled: Bool
    let recordingDisabledReason: String?
    let recordingDisabledMessage: String?
    let questions: [APIQuestion]
    let audioConstraints: AudioConstraints
}

struct CallAcceptBody: Encodable {
    let requestId: String?
}

struct CallAccepted: Decodable {
    let callId: String
    let livekitUrl: String
    let roomName: String
    let accessToken: String
    let rawCaptureRequired: Bool
    let audioConstraints: AudioConstraints
    let recordingEnabled: Bool?
}

struct DeviceCreated: Decodable {
    let deviceId: String
}

struct RawAudioUpload: Decodable {
    let uploadUrl: String
    let assetId: String
    let expiresIn: Int
}

struct OtpRequestBody: Encodable {
    let phone: String
    let role: String
    let name: String
}

struct OtpVerifyBody: Encodable {
    let phone: String
    let code: String
}

struct DeviceCreateBody: Encodable {
    let platform: String
    let token: String
    let voipToken: String?
    let callNotificationsEnabled: Bool
    let pushToken: String?
    let reportNotificationsEnabled: Bool
}

struct CallCreateBody: Encodable {
    let calleeId: String
}

struct RawAudioUploadBody: Encodable {
    let contentType: String
    let durationSec: Double
    let sampleRate: Int
}

struct RawAudioCompleteBody: Encodable {
    let assetId: String
}

struct ConsentSubmitBody: Encodable {
    let documentVersion: String
    let decision: String
    let scrolledToEnd: Bool
    let agreedItems: [String]
}

struct ProfilePutBody: Encodable {
    let conditions: [String]
    /// nil 이면 키를 보내지 않아 서버가 저장된 값을 그대로 둔다. 빈 문자열은 지운다.
    let concerns: String?
}

struct InvitationCreateBody: Encodable {
    let name: String
    let relation: String
}

struct InvitationAcceptBody: Encodable {
    let code: String
}

// 오늘 할 일 (개인용, 가족과 공유하지 않는다)
struct TodoDTO: Decodable, Identifiable, Equatable {
    enum Source: String, Decodable {
        case suggested = "SUGGESTED"
        case user = "USER"
    }

    let id: String
    let title: String
    let source: Source
    var done: Bool
    let doneAt: Date?
    let createdAt: Date
}

struct TodoListResponse: Decodable {
    let date: String
    let items: [TodoDTO]
}

struct TodoCreateBody: Encodable {
    let title: String
}

struct TodoDoneBody: Encodable {
    let done: Bool
}

// MARK: - 건강 앱 연결 (2026-11-08 서버·안드로이드 공통 약속)

/// 서버가 내려주는 별도 선택 동의 문서. 앱은 그대로 보여 준다.
struct HealthLinkDocument: Codable, Equatable {
    let version: String
    let title: String
    let items: [String]
}

/// `GET/POST /v1/health/link`. 시각·날짜는 글자로 받는다(형식이 달라도 응답 전체가 깨지지 않게).
struct HealthLinkStatusDTO: Codable, Equatable {
    var connected = false
    var consentVersion: String?
    var connectedAt: String?
    var document: HealthLinkDocument?
    /// "yyyy-MM-dd"
    var lastSyncedDay: String?
}

struct HealthLinkBody: Encodable {
    let version: String
    let platform: String
}

/// 하루 요약 한 줄. 그날 기록이 없는 값은 nil(보낼 때 그 칸은 빠진다).
struct HealthDayDTO: Codable, Equatable {
    /// Asia/Seoul 기준 "yyyy-MM-dd"
    let date: String
    var sleepMinutes: Int?
    var steps: Int?
    var restingHeartRate: Int?
    var bloodPressureSystolic: Int?
    var bloodPressureDiastolic: Int?
    var bloodGlucoseMgDl: Double?

    var hasAnyValue: Bool {
        sleepMinutes != nil || steps != nil || restingHeartRate != nil
            || bloodPressureSystolic != nil || bloodPressureDiastolic != nil || bloodGlucoseMgDl != nil
    }
}

struct HealthDailyUploadBody: Encodable {
    let platform: String
    let days: [HealthDayDTO]
}

struct HealthDailyUploadResult: Decodable {
    let saved: Int
    let lastSyncedDay: String?
}

/// `GET /v1/parents/{parentId}/health/daily`. 연결 안 됐으면 `days`가 비어 있다.
struct ParentHealthDailyDTO: Decodable {
    let parentId: String
    let connected: Bool
    let platform: String?
    let lastSyncedDay: String?
    let days: [HealthDayDTO]
    let disclaimer: String?
}
