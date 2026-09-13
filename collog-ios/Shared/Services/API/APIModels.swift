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
    var isCallable: Bool { userId != nil }

    var relationTitle: String {
        switch relation {
        case "MOTHER": "어머니"
        case "FATHER": "아버지"
        case "CHILD": "자녀"
        case "PARENT": "부모"
        default: name
        }
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
}

struct InvitationCreateBody: Encodable {
    let name: String
    let relation: String
}

struct InvitationAcceptBody: Encodable {
    let code: String
}
