//
//  HealthLink.swift
//  collog-ios
//

import Foundation

/// 건강 앱 연결(2026-11-08 약속): 내 연결 상태, 연결 흐름(동의 → 권한 → 연결 → 동기화), 하루 한 번 이하 동기화.
/// 앱 전체에서 하나다(`AppEnvironment.health`). 서버에 API 가 없으면(404 등) 조용히 「준비 중」으로 둔다.
@Observable
final class HealthLink {
    enum Status: Equatable {
        case unknown
        /// 서버에 아직 건강 연결 API 가 없다(404 등). 진입점은 「준비 중」으로 둔다.
        case unsupported
        case failed(String)
        case loaded(HealthLinkStatusDTO)
    }

    /// 연결 시트에 보이는 단계.
    enum Step: Equatable {
        case loading
        case notReady
        case unavailable
        case consent(HealthLinkDocument, notice: String?)
        /// 권한 창을 띄웠거나 서버에 연결하는 중.
        case connecting
        /// `needsPermission`: 이 휴대폰에서 아직 건강 앱 권한 창을 거치지 않아 기록을 읽을 수 없다.
        case linked(justConnected: Bool, lastSyncedDay: String?, needsPermission: Bool)
        case failed(String)
    }

    static let failedText = "건강 앱 연결 상태를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."

    /// 「준비 중」을 받은 뒤 이만큼 지나면 다시 묻는다.
    static let unsupportedRecheck: TimeInterval = 30 * 60

    var isPresented = false
    private(set) var step: Step = .loading
    /// 연결·동기화·끊기가 끝날 때마다 오른다. 리포트가 「생활 기록」을 다시 불러온다.
    private(set) var revision = 0
    private var status: Status = .unknown
    private var statusOwner: String?
    private var hintRevision = 0

    @ObservationIgnored private var statusCheckedAt: Date?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private let source: HealthRecordSource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    init(
        source: HealthRecordSource = HealthKitSource(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.source = source
        self.defaults = defaults
        self.now = now
    }

    var isHealthAvailable: Bool { source.isAvailable }

    /// `userId`의 연결 상태. 다른 계정의 것이면 unknown.
    func status(for userId: String?) -> Status {
        userId != nil && userId == statusOwner ? status : .unknown
    }

    /// 설정 「건강 앱 연결」 줄 오른쪽 글자.
    func rowText(for userId: String?) -> String? {
        switch status(for: userId) {
        case let .loaded(link):
            if link.connected { return "연결됨" }
            return source.isAvailable ? "연결 안 됨" : "지원 안 함"
        case .unsupported:
            return "준비 중"
        case .unknown, .failed:
            return nil
        }
    }

    /// 홈 안내 카드: 아직 연결하지 않았고, 건강 앱을 쓸 수 있는 기기이고, 닫은 적이 없을 때.
    func shouldShowHint(using environment: AppEnvironment) -> Bool {
        _ = hintRevision
        guard let userId = userId(environment), source.isAvailable,
              !defaults.bool(forKey: Self.hintKey(userId)),
              case let .loaded(link) = status(for: userId) else { return false }
        return !link.connected
    }

    func dismissHint(using environment: AppEnvironment) {
        guard let userId = userId(environment) else { return }
        defaults.set(true, forKey: Self.hintKey(userId))
        hintRevision += 1
    }

    /// 아직 이 계정의 상태를 모르면(또는 못 불러왔으면) 불러온다. 「준비 중」은 마지막 확인에서 30분이 지났으면 다시 묻는다.
    func ensureStatus(using environment: AppEnvironment) async {
        guard let userId = userId(environment) else { return }
        switch status(for: userId) {
        case .loaded:
            return
        case .unsupported:
            if let checkedAt = statusCheckedAt, now().timeIntervalSince(checkedAt) < Self.unsupportedRecheck { return }
        case .unknown, .failed:
            break
        }
        await refreshStatus(using: environment)
    }

    @discardableResult
    func refreshStatus(using environment: AppEnvironment) async -> Status {
        guard let userId = userId(environment) else { return .unknown }
        let next: Status
        do {
            next = .loaded(try await environment.api.healthLink())
        } catch {
            next = Self.isUnsupported(error) ? .unsupported : .failed(error.localizedDescription)
        }
        guard environment.session.user?.id == userId else { return .unknown }
        setStatus(next, for: userId)
        return next
    }

    func present() {
        step = .loading
        isPresented = true
    }

    /// 시트를 열 때: 기기·서버 상태에 맞는 단계를 고른다.
    func prepare(using environment: AppEnvironment) async {
        step = .loading
        guard source.isAvailable else {
            step = .unavailable
            return
        }
        switch await refreshStatus(using: environment) {
        case .unknown:
            step = .failed(Self.failedText)
        case .unsupported:
            step = .notReady
        case let .failed(message):
            step = .failed(message)
        case let .loaded(link):
            if link.connected {
                step = .linked(
                    justConnected: false,
                    lastSyncedDay: link.lastSyncedDay,
                    needsPermission: await source.needsAuthorization()
                )
            } else if let document = link.document {
                step = .consent(document, notice: nil)
            } else {
                step = .failed("동의 문서를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    /// 「동의하고 연결」: 권한 창이 오류 없이 닫히면 동의를 서버에 남기고 바로 동기화한다.
    /// HealthKit 은 읽기 권한을 허용했는지 알려 주지 않으므로, 기록이 없어도 연결은 유지한다.
    func connect(_ document: HealthLinkDocument, using environment: AppEnvironment) async {
        guard let userId = userId(environment) else { return }
        step = .connecting
        do {
            try await source.requestAuthorization()
        } catch {
            step = .failed("건강 앱 권한을 요청하지 못했어요. 잠시 후 다시 시도해 주세요.")
            return
        }
        let link: HealthLinkStatusDTO
        do {
            link = try await environment.api.connectHealthLink(version: document.version)
        } catch {
            if Self.isUnsupported(error) {
                setStatus(.unsupported, for: userId)
                step = .notReady
            } else if case let .server(_, code, _) = error as? APIError, code == "HEALTH_CONSENT_VERSION_MISMATCH" {
                if case let .loaded(refreshed) = await refreshStatus(using: environment), let latest = refreshed.document {
                    step = .consent(latest, notice: "동의 문서가 바뀌었어요. 다시 읽고 동의해 주세요.")
                } else {
                    step = .failed(Self.failedText)
                }
            } else {
                step = .failed(error.localizedDescription)
            }
            return
        }
        guard environment.session.user?.id == userId else { return }
        var connected = link
        connected.connected = true
        setStatus(.loaded(connected), for: userId)
        let before = revision
        await sync(using: environment, force: true)
        // 리포트는 동기화가 끝난 뒤 한 번만 다시 불러오게 한다
        if revision == before { revision += 1 }
        Haptics.commit()
        step = .linked(justConnected: true, lastSyncedDay: currentLink(userId)?.lastSyncedDay, needsPermission: false)
    }

    /// 연결된 뒤 이 휴대폰에서 권한 창을 다시 거칠 때(앱을 다시 깔았거나 다른 휴대폰에서 연결함).
    func regrant(using environment: AppEnvironment) async {
        guard let userId = userId(environment) else { return }
        step = .loading
        do {
            try await source.requestAuthorization()
        } catch {
            step = .failed("건강 앱 권한을 요청하지 못했어요. 잠시 후 다시 시도해 주세요.")
            return
        }
        await sync(using: environment, force: true)
        step = .linked(justConnected: false, lastSyncedDay: currentLink(userId)?.lastSyncedDay, needsPermission: false)
    }

    /// 연결 끊기: 서버가 요약을 지운다. HealthKit 권한은 앱에서 거둘 수 없어 건강 앱 설정에 남지만, 더는 읽지 않는다.
    func disconnect(using environment: AppEnvironment) async {
        guard let userId = userId(environment) else { return }
        step = .loading
        do {
            try await environment.api.disconnectHealthLink()
        } catch {
            step = .failed(error.localizedDescription)
            return
        }
        defaults.removeObject(forKey: Self.syncKey(userId))
        var link = currentLink(userId) ?? HealthLinkStatusDTO()
        link.connected = false
        link.lastSyncedDay = nil
        setStatus(.loaded(link), for: userId)
        revision += 1
        isPresented = false
    }

    /// 앱이 앞으로 올 때: 오늘 아직 보내지 않았고 연결돼 있으면 최근 14일을 다시 계산해 올린다.
    func syncIfDue(using environment: AppEnvironment) async {
        guard let userId = userId(environment) else { return }
        if defaults.string(forKey: Self.syncKey(userId)) == todayKey { return }
        await ensureStatus(using: environment)
        guard currentLink(userId)?.connected == true else { return }
        await sync(using: environment, force: false)
    }

    /// 동기화는 한 번에 하나만 돈다. 먼저 돌던 것이 끝나기를 기다린 뒤 이어서 돈다.
    private func sync(using environment: AppEnvironment, force: Bool) async {
        while let running = syncTask { await running.value }
        let task = Task {
            await performSync(using: environment, force: force)
            syncTask = nil
        }
        syncTask = task
        await task.value
    }

    /// 최근 14일을 다시 계산해 기록이 있는 날만 올린다. 기록이 하나도 없으면(권한을 허용하지 않았거나 정말 없음)
    /// 보내지 않고 오늘 보냈다고 적지도 않는다. 건강 앱 권한을 나중에 켜도 앱을 다시 열 때 보내게 하려는 것이다.
    private func performSync(using environment: AppEnvironment, force: Bool) async {
        guard let userId = userId(environment) else { return }
        let today = todayKey
        if !force, defaults.string(forKey: Self.syncKey(userId)) == today { return }
        guard source.isAvailable else { return }

        let days = HealthDailyCalculator.syncDays(today: now())
        let summaries: [HealthDayDTO]
        do {
            summaries = HealthDailyCalculator.summaries(days: days, records: try await source.read(days: days))
        } catch {
            return
        }
        let sending = summaries.filter(\.hasAnyValue)
        guard !sending.isEmpty, environment.session.user?.id == userId else { return }

        do {
            let result = try await environment.api.uploadHealthDaily(days: sending)
            guard environment.session.user?.id == userId else { return }
            if var link = currentLink(userId) {
                link.lastSyncedDay = result.lastSyncedDay ?? link.lastSyncedDay
                setStatus(.loaded(link), for: userId)
            }
            defaults.set(today, forKey: Self.syncKey(userId))
            revision += 1
        } catch {
            guard environment.session.user?.id == userId else { return }
            if Self.isUnsupported(error) {
                setStatus(.unsupported, for: userId)
            } else if case let .server(_, code, _) = error as? APIError, code == "HEALTH_LINK_REQUIRED" {
                var link = currentLink(userId) ?? HealthLinkStatusDTO()
                link.connected = false
                setStatus(.loaded(link), for: userId)
            }
            // 서버가 받지 않은 요청(4xx)은 같은 날 다시 보내지 않는다. 연결·서버 오류는 다음에 앞으로 올 때 다시.
            if case let .server(status, _, _) = error as? APIError, (400..<500).contains(status) {
                defaults.set(today, forKey: Self.syncKey(userId))
            }
        }
    }

    private var todayKey: String { HealthDailyCalculator.dayString(HealthDailyCalculator.dayOf(now())) }

    private func currentLink(_ userId: String) -> HealthLinkStatusDTO? {
        if case let .loaded(link) = status(for: userId) { return link }
        return nil
    }

    private func setStatus(_ next: Status, for userId: String) {
        statusOwner = userId
        status = next
        statusCheckedAt = now()
    }

    /// 체험 모드·로그아웃 상태에서는 아무것도 하지 않는다(HealthKit·서버 모두).
    private func userId(_ environment: AppEnvironment) -> String? {
        guard environment.session.isAuthenticated, !environment.settings.isGuestMode else { return nil }
        return environment.session.user?.id
    }

    private static func syncKey(_ userId: String) -> String { "health.lastSyncDay.\(userId)" }
    private static func hintKey(_ userId: String) -> String { "health.hintDismissed.\(userId)" }

    /// 서버에 아직 이 API 가 없을 때(경로 없음·메서드 없음·미구현).
    private static func isUnsupported(_ error: Error) -> Bool {
        guard case let .server(status, _, _) = error as? APIError else { return false }
        return [404, 405, 501].contains(status)
    }
}
