//
//  UsageEventLog.swift
//  collog-ios
//

import Foundation

/// 이용 기록(앱 이벤트) 서버·앱 약속(2026-11-24)의 이벤트 한 줄. 서버에 이 모양 그대로 보낸다.
/// 사용자·대상·통화 ID·시각·플랫폼·앱 버전·정해진 코드값만 담는다(질환·문장·통화 내용·전화번호·자유 입력 금지).
struct UsageEvent: Codable, Equatable {
    let id: String
    let name: String
    let at: String
    let platform: String
    let appVersion: String
    var code: String?
    var subjectId: String?
    var callId: String?
}

/// 이용 기록을 기기에 쌓아 두었다가 묶어서 보낸다. 실패는 조용히 넘긴다(화면·통화를 막지 않는다).
/// 쌓을 때 로그인한 사용자를 같이 적고, 보낼 때는 지금 로그인한 사용자 것만 보낸다.
/// 둘러보기(게스트)에서는 아무것도 남기지 않고, 로그아웃·계정 삭제 때 쌓인 것을 지운다.
final class UsageEventLog {
    /// 로그인한 사용자가 남기는 이벤트. 이벤트마다 약속이 허용한 코드·대상·통화 칸만 받는다.
    enum Event {
        case appOpen
        case reportView(ReportSource, subjectId: String?)
        case postCallAnswer(CallCenter.PostCallQuestion.Answer, subjectId: String?, callId: String)
        case incomingCallShown(callId: String)
        case callConnectFailed(CallConnectFailure, callId: String?)
        case healthLinkResult(HealthLinkResult)
    }

    enum ReportSource: String {
        case direct = "DIRECT"
        case notification = "NOTIFICATION"
    }

    enum HealthLinkResult: String {
        case connected = "CONNECTED"
        case connectedNoRecords = "CONNECTED_NO_RECORDS"
    }

    /// `onboarding_step`의 단계 이름 가운데 이 앱에 있는 것(TERMS·PROFILE 화면은 없다).
    enum OnboardingStep: String {
        case welcome = "WELCOME"
        case login = "LOGIN"
        case inviteCode = "INVITE_CODE"
        case aiConsent = "AI_CONSENT"
        case conditions = "CONDITIONS"
        case done = "DONE"

        /// 로그인 전 단계는 익명 주소로 보낸다.
        var isBeforeLogin: Bool { self == .welcome || self == .login }
    }

    private enum Name: String {
        case appOpen = "app_open"
        case reportView = "report_view"
        case postCallAnswer = "post_call_answer"
        case incomingCallShown = "incoming_call_shown"
        case callConnectFailed = "call_connect_failed"
        case onboardingStep = "onboarding_step"
        case healthLinkResult = "health_link_result"
    }

    enum Key {
        static let pending = "usage.pendingEvents"
        static let onboardingSteps = "usage.onboardingSteps"
        static func appOpenDay(_ userId: String) -> String { "usage.appOpenDay.\(userId)" }
    }

    /// 기기에 쌓아 두는 최대 개수. 넘치면 오래된 것부터 버린다.
    static let capacity = 200
    static let batchLimit = 50
    static let anonymousBatchLimit = 20

    private struct Entry: Codable {
        /// 쌓을 때 로그인해 있던 사용자. nil 이면 로그인 전 단계라 익명 주소로 보낸다.
        let userId: String?
        let event: UsageEvent
    }

    private static let timestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let defaults: UserDefaults
    private let sendsAutomatically: Bool
    private let now: () -> Date
    private var flushTask: Task<Void, Never>?
    private var needsFlush = false

    /// `sendsAutomatically`가 false 면 쌓기만 하고 `flush`를 부를 때만 보낸다(시험용).
    init(defaults: UserDefaults = .standard, sendsAutomatically: Bool = true, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.sendsAutomatically = sendsAutomatically
        self.now = now
    }

    /// 아직 보내지 않은 이벤트, 오래된 것부터.
    var pendingEvents: [UsageEvent] { entries().map(\.event) }

    /// 「버전 (빌드)」, 40자 이내.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String("\(version) (\(build))".prefix(40))
    }

    /// 로그인한 사용자의 이벤트를 쌓는다. 로그인 전·둘러보기에서는 남기지 않는다.
    func record(_ event: Event, using environment: AppEnvironment) {
        guard let userId = Self.recordingUser(environment) else { return }
        append(Entry(userId: userId, event: usageEvent(event)), using: environment)
    }

    /// 앱이 앞으로 올 때: 그날(서울 날짜) 첫 번째면 `app_open`을 남기고, 쌓인 것을 보낸다.
    func appDidBecomeActive(using environment: AppEnvironment) {
        if let userId = Self.recordingUser(environment) {
            let today = HealthDailyCalculator.dayString(HealthDailyCalculator.dayOf(now()))
            if defaults.string(forKey: Key.appOpenDay(userId)) != today {
                defaults.set(today, forKey: Key.appOpenDay(userId))
                record(.appOpen, using: environment)
                return
            }
        }
        sendSoon(using: environment)
    }

    /// 가입 단계 화면에 처음 들어왔을 때, 단계마다 설치당 한 번. 로그인 전 단계는 익명으로 남긴다.
    func recordOnboardingStep(
        from previous: AuthFlowViewModel.Step, to step: AuthFlowViewModel.Step, using environment: AppEnvironment
    ) {
        guard !environment.settings.isGuestMode, let code = Self.onboardingCode(from: previous, to: step) else { return }
        var recorded = Set(defaults.stringArray(forKey: Key.onboardingSteps) ?? [])
        guard !recorded.contains(code.rawValue) else { return }
        var userId: String?
        if !code.isBeforeLogin {
            guard let current = Self.recordingUser(environment) else { return }
            userId = current
        }
        recorded.insert(code.rawValue)
        defaults.set(recorded.sorted(), forKey: Key.onboardingSteps)
        append(Entry(userId: userId, event: makeEvent(.onboardingStep, code: code.rawValue)), using: environment)
    }

    /// 단계 화면과 약속의 단계 이름.
    static func onboardingCode(from previous: AuthFlowViewModel.Step, to step: AuthFlowViewModel.Step) -> OnboardingStep? {
        switch step {
        case .launching: nil
        case .onboarding: .welcome
        case .login: .login
        case .invitation: .inviteCode
        case .consent: .aiConsent
        case .profile: .conditions
        // 가입 단계를 거쳐 홈에 왔을 때만. 이미 가입한 사람이 앱을 열어 바로 홈으로 가면 남기지 않는다.
        case .ready: previous == .launching || previous == .ready ? nil : .done
        }
    }

    /// 로그아웃·계정 삭제 때 쌓인 것을 지운다.
    func clear() {
        defaults.removeObject(forKey: Key.pending)
    }

    /// 쌓인 것을 묶어 보낸다. 이미 보내는 중이면 그것이 끝난 뒤 한 번 더 본다.
    func flush(using environment: AppEnvironment) async {
        needsFlush = true
        if flushTask == nil {
            flushTask = Task {
                while needsFlush {
                    needsFlush = false
                    await sendPending(using: environment)
                }
                flushTask = nil
            }
        }
        await flushTask?.value
    }

    private func sendSoon(using environment: AppEnvironment) {
        guard sendsAutomatically else { return }
        Task { await flush(using: environment) }
    }

    private func sendPending(using environment: AppEnvironment) async {
        await send(for: nil, limit: Self.anonymousBatchLimit, using: environment)
        guard let userId = Self.recordingUser(environment) else { return }
        await send(for: userId, limit: Self.batchLimit, using: environment)
    }

    /// `userId`가 nil 이면 로그인 전 단계를 익명 주소로, 아니면 그 사용자 것을 로그인 주소로 보낸다.
    /// 2xx 면 지운다. 연결 오류·5xx·401 이면 남겨 두고 멈춘다. 그 밖의 4xx 는 그 묶음을 버린다.
    private func send(for userId: String?, limit: Int, using environment: AppEnvironment) async {
        while true {
            if let userId, Self.recordingUser(environment) != userId { return }
            let batch = Array(entries().filter { $0.userId == userId }.prefix(limit))
            guard !batch.isEmpty else { return }
            do {
                try await environment.api.sendEvents(batch.map(\.event), anonymous: userId == nil)
            } catch APIError.server(let status, _, _) where status < 500 {
                // 서버가 받지 않는 묶음(404 = 아직 이 주소가 없음 포함)은 버린다
            } catch {
                return
            }
            let sent = Set(batch.map(\.event.id))
            save(entries().filter { !sent.contains($0.event.id) })
        }
    }

    private func append(_ entry: Entry, using environment: AppEnvironment) {
        var all = entries()
        all.append(entry)
        if all.count > Self.capacity { all.removeFirst(all.count - Self.capacity) }
        save(all)
        sendSoon(using: environment)
    }

    private func usageEvent(_ event: Event) -> UsageEvent {
        switch event {
        case .appOpen:
            makeEvent(.appOpen)
        case let .reportView(source, subjectId):
            makeEvent(.reportView, code: source.rawValue, subjectId: subjectId)
        case let .postCallAnswer(answer, subjectId, callId):
            makeEvent(.postCallAnswer, code: answer.rawValue, subjectId: subjectId, callId: callId)
        case let .incomingCallShown(callId):
            makeEvent(.incomingCallShown, callId: callId)
        case let .callConnectFailed(failure, callId):
            makeEvent(.callConnectFailed, code: failure.rawValue, callId: callId)
        case let .healthLinkResult(result):
            makeEvent(.healthLinkResult, code: result.rawValue)
        }
    }

    private func makeEvent(_ name: Name, code: String? = nil, subjectId: String? = nil, callId: String? = nil) -> UsageEvent {
        UsageEvent(
            id: UUID().uuidString.lowercased(),
            name: name.rawValue,
            at: Self.timestamp.string(from: now()),
            platform: "IOS",
            appVersion: Self.appVersion,
            code: code,
            subjectId: subjectId,
            callId: callId
        )
    }

    private func entries() -> [Entry] {
        defaults.data(forKey: Key.pending).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    private func save(_ entries: [Entry]) {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else {
            defaults.removeObject(forKey: Key.pending)
            return
        }
        defaults.set(data, forKey: Key.pending)
    }

    /// 이벤트를 남길 사용자: 로그인했고 둘러보기가 아닐 때만.
    private static func recordingUser(_ environment: AppEnvironment) -> String? {
        guard environment.session.isAuthenticated, !environment.settings.isGuestMode else { return nil }
        return environment.session.user?.id
    }
}
