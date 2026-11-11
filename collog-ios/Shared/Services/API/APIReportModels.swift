//
//  APIReportModels.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct ConsentDocument: Decodable {
    let version: String
    let fullText: String
    let collectedItems: [String]
    let purpose: String
    let retentionPeriod: String
    let rawAudioPolicy: String
    let requiredItems: [String]
}

enum ConsentItemLabel {
    static func korean(for code: String) -> String {
        switch code {
        case "SENSITIVE_HEALTH_COLLECTION": "건강 민감정보 수집·이용"
        case "VOICE_FEATURE_EXTRACTION": "음성 특징값 추출"
        case "CALL_RECORDING": "통화 녹음과 분석"
        case "REPORT_SHARING_WITH_CHILD": "자녀와 리포트 공유"
        case "THIRD_PARTY_AI_PROCESSING": "Deepgram, Google Gemini, ElevenLabs에 데이터 전송"
        default: code
        }
    }
}

struct ConsentRecordDTO: Decodable {
    let consentId: String
    let userId: String
    let documentVersion: String
    let status: String
    let agreedItems: [String]
    let isCurrent: Bool
    let currentDocumentVersion: String

    var isGranted: Bool { status == "GRANTED" }
}

struct ProfileDTO: Decodable {
    let parentId: String
    let conditions: [String]
    let isCompleted: Bool?
    let updatedAt: Date?

    var hasCompletedSetup: Bool { isCompleted ?? (updatedAt != nil || !conditions.isEmpty) }
}

struct InvitationDTO: Decodable {
    let invitationId: String
    let code: String
    let shareText: String
    let status: String
}

struct CallSummaryDTO: Decodable, Identifiable {
    let callId: String
    let parentId: String
    let state: String
    let timeSlot: String?
    let startedAt: Date
    let endedAt: Date?
    let durationSec: Int?
    let recorded: Bool
    let parentSpeechSec: Int?

    var id: String { callId }
    var isAnalyzed: Bool { state == "ANALYZED" }
}

struct CallsResponse: Decodable {
    let calls: [CallSummaryDTO]
}

struct ComparisonDTO: Decodable {
    let deltaPct: Double
    let direction: String
    let robustZ: Double
    let significant: Bool
}

struct SignalDTO: Decodable {
    let signalId: String
    let metric: String
    let timeSlot: String
    let consecutiveWeeks: Int
    let promoted: Bool
    let acute: Bool
    let summaryText: String?
    let acuteText: String?
    let vsAnchor: ComparisonDTO?
    let vsRolling: ComparisonDTO?
}

struct RepeatObservationDTO: Decodable {
    let count: Int
    let callsWithRepeat: Int
    let label: String
}

struct AcousticTrendPointDTO: Decodable {
    let date: String
    let value: Double?
    let unit: String?
}

struct AcousticTrendDTO: Decodable {
    let metric: String
    let points: [AcousticTrendPointDTO]
}

struct ReportDTO: Decodable {
    let parentId: String
    let period: String
    let from: String
    let to: String
    let state: String
    let emptyMessage: String?
    let disclaimer: String
    let advisory: String?
    let promotedSignals: [SignalDTO]
    let acuteSignals: [SignalDTO]
    let conversationItems: [String: [String]]
    let repeatObservation: RepeatObservationDTO
    let acousticTrends: [AcousticTrendDTO]
    let recentAcousticHistory: [AcousticTrendDTO]?
    let analyzedCallCount: Int
    let containsDemoData: Bool?
    let demoDataNotice: String?
    /// 응급 안내(11-08 가드레일). 서버가 아직 보내지 않으면 nil.
    var safetyNotices: [SafetyNoticeDTO]? = nil

    enum CodingKeys: String, CodingKey {
        case parentId, period, from, to, state, emptyMessage, disclaimer, advisory
        case promotedSignals, acuteSignals, conversationItems, repeatObservation
        case acousticTrends, recentAcousticHistory, analyzedCallCount
        case containsDemoData, demoDataNotice, safetyNotices
    }
}

/// 리포트 `safetyNotices` 한 줄: 통화 중 응급 표현이 있었을 때 서버가 고정 문구로 남긴다.
/// 한 줄이 이상해도 리포트 전체가 깨지지 않게 칸마다 따로 읽는다.
struct SafetyNoticeDTO: Decodable {
    let callId: String
    let observedAt: String?
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        callId = (try? container.decodeIfPresent(String.self, forKey: .callId)) ?? ""
        observedAt = try? container.decodeIfPresent(String.self, forKey: .observedAt)
        text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case callId, observedAt, text
    }
}

struct AcousticFeatureDTO: Decodable {
    let metric: String
    let value: Double?
    let unit: String
    let status: String
    let unmeasurableReason: String?

    var isMeasured: Bool { status == "OK" && value != nil }
}

struct AcousticFeaturesDTO: Decodable {
    let callId: String
    let features: [AcousticFeatureDTO]
}

struct ExtractionDTO: Decodable {
    let callId: String
    let parseStatus: String
    let symptom: String?
    let medication: String?
    let activity: String?
    let sleep: String?
    /// 통화 중 응급 표현이 있었을 때의 고정 안내 문구. 없거나 서버가 아직 보내지 않으면 nil.
    var safetyNotice: String? = nil
}

struct RepeatEventDTO: Decodable {
    let startMs: Int
    let endMs: Int
    let category: String
    let matchedText: String
}

struct TranscriptDTO: Decodable {
    let callId: String
    let excluded: Bool
    let parentSpeechSec: Int
    let repeatEvents: [RepeatEventDTO]
    let repeatRequestCount: Int
    let repeatRequestsPerMinute: Double
}

struct BaselineDTO: Decodable {
    let metric: String
    let timeSlot: String
    let kind: String
    let status: String
    let sampleCount: Int
    let requiredCount: Int
    let median: Double?
    let mad: Double?

    var isReady: Bool { status == "READY" && median != nil && (mad ?? 0) > 0 }
}

struct BaselinesResponse: Decodable {
    let baselines: [BaselineDTO]
}

enum MetricLabel {
    static func korean(for metric: String) -> String {
        switch metric {
        case "SPEECH_RATE": "말씀 속도"
        case "PAUSE_RATIO": "말 사이 쉼"
        case "F0_VARIATION": "목소리 높낮이"
        case "COUGH_EVENTS": "기침"
        default: metric
        }
    }

    static func unit(for metric: String) -> String {
        switch metric {
        case "SPEECH_RATE": "음절/분"
        case "PAUSE_RATIO": "%"
        case "F0_VARIATION": "semitone"
        case "COUGH_EVENTS": "회"
        default: ""
        }
    }
}
