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
    let phone: String
    let familyId: String?
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: APIUser
}

struct FamilyMember: Decodable, Identifiable, Hashable {
    let memberId: String
    let userId: String?
    let name: String
    let relation: String
    let status: String

    var id: String { memberId }
    var isCallable: Bool { userId != nil }

    var relationTitle: String {
        switch relation {
        case "MOTHER": "어머니"
        case "FATHER": "아버지"
        default: name
        }
    }
}

struct FamilyMembersResponse: Decodable {
    let members: [FamilyMember]
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
