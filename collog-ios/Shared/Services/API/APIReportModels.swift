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

struct ConsentRecordDTO: Decodable {
    let consentId: String
    let userId: String
    let documentVersion: String
    let status: String
    let agreedItems: [String]

    var isGranted: Bool { status == "GRANTED" }
}

struct ProfileDTO: Decodable {
    let parentId: String
    let conditions: [String]
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

    enum CodingKeys: String, CodingKey {
        case parentId, period, from, to, state, emptyMessage, disclaimer, advisory
        case promotedSignals, acuteSignals, conversationItems, repeatObservation
        case acousticTrends, recentAcousticHistory, analyzedCallCount
        case containsDemoData, demoDataNotice
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
