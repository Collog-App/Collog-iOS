//
//  CallAnalysisViewModel.swift
//  collog-ios
//

import Foundation

/// 통화 하나의 분석. 리포트 응급 안내를 누르면 연다(안드로이드 `CallAnalysisViewModel`과 같은 상태).
/// 분석된 통화는 타임라인과 같은 카드로 보인다.
@Observable
final class CallAnalysisViewModel {
    enum State {
        case loading
        /// 통화가 끝나지 않았거나 분석 중이다.
        case pending
        /// 분석에서 빠졌거나(ANALYSIS_EXCLUDED) 분석하지 못한(ANALYSIS_FAILED) 통화.
        case unavailable(title: String, message: String?, safetyNotice: String?)
        case error(String)
        case ready(CallTimelineEntry)
    }

    let callId: String
    private(set) var state: State = .loading

    init(callId: String) {
        self.callId = callId
    }

    func load(using environment: AppEnvironment) async {
        state = .loading
        do {
            state = try await fetch(environment.api)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func fetch(_ api: CollogAPI) async throws -> State {
        let call = try await api.callSummary(callId: callId)
        switch call.state {
        case "ANALYZED":
            break
        case "ANALYSIS_EXCLUDED":
            // 짧아서 제외된 통화도 응급 표현이 있으면 서버가 안내를 남긴다. 없거나(404) 실패하면 조용히 넘긴다.
            let extraction = try? await api.extraction(callId: callId)
            return .unavailable(
                title: "분석 대상에서 제외된 통화예요.",
                message: "동의가 없거나 대화가 짧은 통화는 분석하지 않아요.",
                safetyNotice: SafetyNotice.text(extraction?.safetyNotice)
            )
        case "ANALYSIS_FAILED":
            return .unavailable(title: "통화를 분석하지 못했어요.", message: nil, safetyNotice: nil)
        default:
            return .pending
        }

        // 타임라인과 같은 기준선·결과. 못 받은 것은 빼고 보여 준다.
        async let features = try? api.acousticFeatures(callId: callId)
        async let extraction = try? api.extraction(callId: callId)
        async let transcript = try? api.transcript(callId: callId)
        let baselines = ((try? await api.baselines(parentId: call.parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [:]) { $0[$1.metric] = $1 }
        let bundle = await CallAnalysisBundle(
            call: call,
            features: features,
            extraction: extraction,
            transcript: transcript
        )
        return .ready(CallTimelineEntry(bundle: bundle, baselines: baselines))
    }
}
