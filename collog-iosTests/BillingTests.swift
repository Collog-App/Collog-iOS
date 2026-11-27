//
//  BillingTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 결제(구독) 1차 약속(2026-11-27): 서버 요금제 해석, 잠금 판단, 402 와 403 구분, 분량 초과 안내,
/// 가족 결제 때 구매 버튼 숨김, 공개 SDK 키가 없을 때의 동작, 구매·취소·실패 뒤 흐름.
@MainActor
struct BillingTests {
    private let premiumRequired = #"{"code":"PREMIUM_REQUIRED","message":"주간 리포트는 프리미엄에서 볼 수 있어요."}"#
    private let denied = #"{"code":"SCOPE_DENIED","message":"열람 권한이 없는 항목입니다"}"#

    // MARK: - 서버 값 해석

    @Test
    func entitlementDecodesTheContractBody() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, self.entitlementBody()) }

        let value = try await fixture.environment.api.entitlement()
        #expect(value.billingEnabled)
        #expect(value.plan == "PREMIUM")
        #expect(value.source == "TRIAL")
        #expect(value.trialEndsAt == Date.fromCollogTimestamp("2026-12-15T00:00:00+00:00"))
        #expect(value.paidUntil == nil)
        #expect(value.paidByMe == false)
        #expect(value.payerName == nil)
        #expect(value.analysis == EntitlementDTO.Analysis(
            month: "2026-12", usedSec: 1260, limitSec: 15000,
            resetsAt: Date.fromCollogTimestamp("2027-01-01T00:00:00+09:00")
        ))
        #expect(fixture.paths == ["/v1/account/entitlement"])
    }

    @Test
    func billingOffKeepsTheAppAsItIs() throws {
        let value = try entitlement(billing: false, plan: "PREMIUM", source: nil, trialEndsAt: nil)
        #expect(!value.locksReports)
        let billing = BillingStore(apiKey: nil)
        #expect(!billing.locksReports)
        #expect(!billing.showsEntryPoints)
    }

    @Test
    func onlyAFreePlanWithBillingOnLocksReports() throws {
        #expect(try entitlement(plan: "FREE", source: nil, trialEndsAt: nil).locksReports)
        #expect(try !entitlement(plan: "PREMIUM", source: "TRIAL").locksReports)
        #expect(try !entitlement(plan: "PREMIUM", source: "PAID", trialEndsAt: nil).locksReports)
        #expect(try !entitlement(billing: false, plan: "FREE", source: nil, trialEndsAt: nil).locksReports)
    }

    @Test
    func storeKeepsTheServerValueAndShowsEntryPointsOnlyWhenBillingIsOn() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let billing = fixture.environment.billing
        fixture.respond = { _ in (200, self.entitlementBody(plan: "FREE", source: nil, trialEndsAt: nil)) }
        await billing.refresh(using: fixture.environment)
        #expect(billing.locksReports)
        #expect(billing.showsEntryPoints)

        // 다시 읽기에 실패하면 가진 값을 그대로 둔다
        fixture.respond = { _ in (503, #"{"code":"ERROR","message":"잠시 후"}"#) }
        await billing.refresh(using: fixture.environment)
        #expect(billing.locksReports)

        fixture.respond = { _ in (200, self.entitlementBody(billing: false, source: nil, trialEndsAt: nil)) }
        await billing.refresh(using: fixture.environment)
        #expect(!billing.locksReports)
        #expect(!billing.showsEntryPoints)
    }

    @Test
    func accountChangeForgetsThePreviousPlan() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, self.entitlementBody(plan: "FREE", source: nil, trialEndsAt: nil)) }
        await fixture.environment.billing.refresh(using: fixture.environment)
        #expect(fixture.environment.billing.entitlement != nil)

        try fixture.environment.session.apply(TokenResponse(
            accessToken: "other", refreshToken: "other",
            user: APIUser(id: "someone-else", role: "CHILD", name: "B", phone: nil, familyId: nil)
        ))
        #expect(fixture.environment.billing.entitlement == nil)
    }

    // MARK: - 402 와 403

    @Test
    func premiumRequiredIsNotSharingOff() {
        let locked = APIError.server(status: 402, code: "PREMIUM_REQUIRED", message: "주간 리포트는 프리미엄에서 볼 수 있어요.")
        let notShared = APIError.server(status: 403, code: "SCOPE_DENIED", message: "열람 권한이 없는 항목입니다")
        #expect(locked.isPremiumRequired)
        #expect(!locked.isForbidden)
        #expect(notShared.isForbidden)
        #expect(!notShared.isPremiumRequired)
    }

    @Test
    func reportPremiumRequiredLocksTheWeekInsteadOfShowingSharingOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveFamily(fixture, calls: (200, #"{"calls":[]}"#), report: (402, premiumRequired))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        let page = model.page(for: 0)
        #expect(page.isLoaded)
        #expect(page.reportLocked)
        #expect(!page.reportNotShared)
        #expect(!page.timelineNotShared)
        #expect(page.reportError == nil)
        #expect(model.hasLockedPage)
    }

    @Test
    func sharingOffStaysSharingOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveFamily(fixture, calls: (200, #"{"calls":[]}"#), report: (403, denied))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        #expect(model.page(for: 0).reportNotShared)
        #expect(!model.page(for: 0).reportLocked)
        #expect(!model.hasLockedPage)
    }

    @Test
    func premiumAgainReadsTheLockedWeeksAgain() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveFamily(fixture, calls: (200, #"{"calls":[]}"#), report: (402, premiumRequired))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.refresh(using: fixture.environment)
        #expect(model.page(for: 0).reportLocked)
        #expect(model.page(for: -1).reportLocked)

        serveFamily(fixture, calls: (200, #"{"calls":[]}"#), report: (200, reportBody()))
        await model.reloadAll(using: fixture.environment)
        #expect(!model.hasLockedPage)
        #expect(model.page(for: 0).report.state != .empty)
    }

    @Test
    func homeHidesReportCardsOnPremiumRequired() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveFamily(fixture, calls: (200, #"{"calls":[]}"#), report: (402, premiumRequired))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: mom)

        #expect(model.isLoaded)
        #expect(model.isReportLocked)
        #expect(!model.isReportNotShared)
        #expect(model.loadError == nil)
        #expect(model.healthSummary == nil)
        #expect(model.healthFeedback == nil)

        // 조용히 다시 읽을 때 잠금 때문에 매번 전체를 다시 읽지 않는다
        let reports = { fixture.paths.filter { $0 == "/v1/parents/mom/reports" }.count }
        let before = reports()
        await model.refreshCalls(using: fixture.environment, contact: mom)
        #expect(reports() == before)
        #expect(model.isReportLocked)
    }

    // MARK: - 분석 분량 초과

    @Test
    func quotaCopyFollowsTheContract() {
        #expect(AnalysisQuota.text(isPremium: false) == "이번 달 무료 분석 시간(40분)을 다 써서 이 통화는 분석하지 않았어요.")
        #expect(AnalysisQuota.text(isPremium: true) == "이번 달 분석 시간을 다 썼어요. 다음 달 1일에 다시 채워져요.")
        #expect(BillingStore.learnMoreTitle == "프리미엄 알아보기")
    }

    @Test
    func quotaExceededCallIsToldApartFromAShortCall() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in
            (200, """
            {"calls":[\(self.callJSON(id: "quota", reason: "ANALYSIS_QUOTA_EXCEEDED")),
                      \(self.callJSON(id: "short", reason: nil)),
                      \(self.callJSON(id: "analyzed", state: "ANALYZED", reason: nil))]}
            """)
        }
        let calls = try await fixture.environment.api.calls(parentId: "mom")
        #expect(calls.map(\.isAnalysisQuotaExceeded) == [true, false, false])
        #expect(calls.first?.recordingDisabledReason == "ANALYSIS_QUOTA_EXCEEDED")

        let resolve = { (call: CallSummaryDTO) in
            AnalysisEmptyAction.resolve(calls: [call], canCall: true, isCurrentWeek: true, isGuest: false)
        }
        #expect(resolve(calls[0]) == .quotaExceeded)
        #expect(resolve(calls[1]) == .excluded)
    }

    @Test
    func callAnalysisShowsTheQuotaStateWithoutAskingForResults() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            request.url?.path == "/v1/calls/quota"
                ? (200, self.callJSON(id: "quota", reason: "ANALYSIS_QUOTA_EXCEEDED"))
                : (404, #"{"detail":"없음"}"#)
        }
        let model = CallAnalysisViewModel(callId: "quota")
        await model.load(using: fixture.environment)

        guard case .quotaExceeded = model.state else {
            Issue.record("분량 초과 상태가 아니에요: \(model.state)")
            return
        }
        // STT·Gemini 를 돌리지 않은 통화라 결과를 묻지 않는다
        #expect(fixture.paths == ["/v1/calls/quota"])
    }

    // MARK: - 결제 화면 상태

    @Test
    func familyPaymentHidesThePurchaseButton() async throws {
        let store = FakeStore()
        let fixture = try TestEnvironment(role: "CHILD", billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        let billing = fixture.environment.billing
        fixture.respond = { _ in
            (200, self.entitlementBody(source: "PAID", trialEndsAt: nil, paidUntil: "2026-12-27T03:00:00+00:00", payerName: "엄마"))
        }
        await billing.refresh(using: fixture.environment)
        await billing.loadPrice(using: fixture.environment)

        #expect(billing.monthlyPrice == "월 ₩13,000")
        #expect(billing.status == .paidByFamily(payerName: "엄마"))
        #expect(!billing.showsPurchaseButton)
        #expect(BillingStore.statusText(billing.status) == "엄마님 덕분에 가족 모두 프리미엄을 쓰고 있어요")
    }

    @Test
    func trialAndFreeOfferThePurchaseButton() async throws {
        let store = FakeStore()
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        let billing = fixture.environment.billing
        fixture.respond = { _ in (200, self.entitlementBody()) }
        await billing.refresh(using: fixture.environment)
        await billing.loadPrice(using: fixture.environment)
        let trialEnd = try #require(Date.fromCollogTimestamp("2026-12-15T00:00:00+00:00"))
        #expect(billing.status == .trial(endsAt: trialEnd))
        #expect(billing.showsPurchaseButton)
        #expect(BillingStore.statusText(billing.status) == "무료 체험 중 · 12월 15일까지")

        fixture.respond = { _ in (200, self.entitlementBody(plan: "FREE", source: nil, trialEndsAt: nil)) }
        await billing.refresh(using: fixture.environment)
        #expect(billing.status == .none)
        #expect(BillingStore.statusText(billing.status) == nil)
        #expect(billing.showsPurchaseButton)
    }

    @Test
    func myOwnSubscriptionShowsTheNextBillingDay() throws {
        let value = try entitlement(source: "PAID", trialEndsAt: nil, paidUntil: "2026-12-27T03:00:00+00:00", paidByMe: true)
        #expect(value.subscriptionStatus == .paidByMe(nextBilling: Date.fromCollogTimestamp("2026-12-27T03:00:00+00:00")))
        #expect(!value.subscriptionStatus.allowsPurchase)
        #expect(BillingStore.statusText(value.subscriptionStatus) == "프리미엄 이용 중 · 다음 결제 12월 27일")
    }

    @Test
    func settingsRowShowsPlanAndThisMonthsAnalysis() throws {
        #expect(try BillingStore.planText(entitlement()) == "프리미엄 · 무료 체험 12월 15일까지")
        #expect(try BillingStore.planText(entitlement(source: "PAID", trialEndsAt: nil)) == "프리미엄")
        #expect(try BillingStore.planText(entitlement(plan: "FREE", source: nil, trialEndsAt: nil)) == "무료")
        #expect(BillingStore.usageText(.init(month: "2026-12", usedSec: 1260, limitSec: 15000, resetsAt: nil)) == "21분 / 250분")
        #expect(BillingStore.usageText(.init(month: "2026-12", usedSec: 720, limitSec: 2400, resetsAt: nil)) == "12분 / 40분")
    }

    @Test
    func lockAndPaywallCopyFollowTheContract() {
        #expect(BillingStore.lockTitle == "주간 리포트와 타임라인은 프리미엄에서 볼 수 있어요")
        #expect(BillingStore.lockMessage == "통화가 쌓이면 부모님의 변화를 한 주, 한 달 단위로 모아 보여드려요.")
        #expect(PaywallView.title == "콜록 프리미엄")
        #expect(PaywallView.benefits == [
            "주간·월간 리포트로 부모님 변화를 한눈에",
            "증상 타임라인으로 지난 통화를 날짜별로",
            "통화 분석 월 250분 (무료는 40분)"
        ])
        #expect(PaywallView.renewalText == "매월 자동으로 결제되고, 언제든 해지할 수 있어요.")
        #expect(PaywallView.purchaseTitle == "프리미엄 시작하기")
        #expect(PaywallView.termsURL.absoluteString == "https://privacy.collog.live/terms.html")
        #expect(PaywallView.privacyURL.absoluteString == "https://privacy.collog.live/")
    }

    // MARK: - 공개 SDK 키

    @Test(arguments: [nil, "", "  ", "$(REVENUECAT_API_KEY)"])
    func missingKeyNeverTouchesTheStore(key: String?) async throws {
        var made = 0
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: key) { _ in
            made += 1
            return FakeStore()
        })
        defer { fixture.cleanUp() }
        let billing = fixture.environment.billing
        fixture.respond = { _ in (200, self.entitlementBody(plan: "FREE", source: nil, trialEndsAt: nil)) }

        await billing.start(using: fixture.environment)
        await billing.loadPrice(using: fixture.environment)
        await billing.purchase(using: fixture.environment)

        #expect(made == 0)
        #expect(!billing.isStoreAvailable)
        #expect(billing.monthlyPrice == nil)
        #expect(!billing.showsPurchaseButton)
        #expect(BillingStore.preparingText == "결제를 준비하고 있어요")
        // 서버 요금제는 키와 상관없이 읽는다(잠금은 서버 값으로)
        #expect(billing.locksReports)
        #expect(fixture.paths == ["/v1/account/entitlement"])
    }

    @Test
    func storeIsToldTheServerUserIdAndGuestsAreLeftAlone() async throws {
        let store = FakeStore()
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, self.entitlementBody()) }
        await fixture.environment.billing.start(using: fixture.environment)
        #expect(store.identified == ["me"])

        fixture.environment.settings.isGuestMode = true
        let requests = fixture.paths.count
        await fixture.environment.billing.start(using: fixture.environment)
        await fixture.environment.billing.loadPrice(using: fixture.environment)
        #expect(store.identified == ["me"])
        #expect(fixture.paths.count == requests)
    }

    // MARK: - 구매·복원

    @Test
    func purchaseAsksTheServerToReadTheStoreAgain() async throws {
        let store = FakeStore()
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            request.url?.path == "/v1/account/entitlement/refresh" && request.httpMethod == "POST"
                ? (200, self.entitlementBody(source: "PAID", trialEndsAt: nil, paidUntil: "2026-12-27T03:00:00+00:00", paidByMe: true))
                : (404, #"{"detail":"없음"}"#)
        }
        await fixture.environment.billing.purchase(using: fixture.environment)

        #expect(store.purchases == 1)
        #expect(fixture.paths == ["/v1/account/entitlement/refresh"])
        #expect(fixture.environment.billing.entitlement?.paidByMe == true)
        #expect(fixture.environment.billing.errorText == nil)
        #expect(!fixture.environment.billing.isWorking)
    }

    @Test
    func cancelledPurchaseStaysQuiet() async throws {
        let store = FakeStore()
        store.purchaseResult = .success(false)
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        await fixture.environment.billing.purchase(using: fixture.environment)

        #expect(store.purchases == 1)
        #expect(fixture.paths.isEmpty)
        #expect(fixture.environment.billing.errorText == nil)
    }

    @Test
    func failedPurchaseShowsTheContractMessage() async throws {
        let store = FakeStore()
        store.purchaseResult = .failure(URLError(.notConnectedToInternet))
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        await fixture.environment.billing.purchase(using: fixture.environment)

        #expect(fixture.paths.isEmpty)
        #expect(fixture.environment.billing.errorText == "결제를 마치지 못했어요. 잠시 뒤 다시 시도해 주세요.")
    }

    @Test
    func restoreAlsoRefreshesAndFallsBackToTheSavedValue() async throws {
        let store = FakeStore()
        let fixture = try TestEnvironment(billing: BillingStore(apiKey: "appl_test") { _ in store })
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            request.url?.path == "/v1/account/entitlement"
                ? (200, self.entitlementBody(source: "PAID", trialEndsAt: nil, paidByMe: true))
                : (503, #"{"code":"ERROR","message":"잠시 후"}"#)
        }
        await fixture.environment.billing.restore(using: fixture.environment)

        #expect(store.restores == 1)
        #expect(fixture.paths == ["/v1/account/entitlement/refresh", "/v1/account/entitlement"])
        #expect(fixture.environment.billing.entitlement?.paidByMe == true)
    }

    // MARK: - Fixtures

    private var mom: FamilyContact {
        FamilyContact(id: "mom", userId: "mom", name: "mom", relation: "MOTHER", lastCallText: "")
    }

    private func entitlement(
        billing: Bool = true, plan: String = "PREMIUM", source: String? = "TRIAL",
        trialEndsAt: String? = "2026-12-15T00:00:00+00:00", paidUntil: String? = nil,
        paidByMe: Bool = false, payerName: String? = nil
    ) throws -> EntitlementDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = Date.fromCollogTimestamp(raw) else { throw URLError(.cannotParseResponse) }
            return date
        }
        return try decoder.decode(EntitlementDTO.self, from: Data(entitlementBody(
            billing: billing, plan: plan, source: source, trialEndsAt: trialEndsAt,
            paidUntil: paidUntil, paidByMe: paidByMe, payerName: payerName
        ).utf8))
    }

    private func entitlementBody(
        billing: Bool = true, plan: String = "PREMIUM", source: String? = "TRIAL",
        trialEndsAt: String? = "2026-12-15T00:00:00+00:00", paidUntil: String? = nil,
        paidByMe: Bool = false, payerName: String? = nil
    ) -> String {
        func json(_ value: String?) -> String { value.map { "\"\($0)\"" } ?? "null" }
        return """
        {"billingEnabled":\(billing),"plan":"\(plan)","source":\(json(source)),
         "trialEndsAt":\(json(trialEndsAt)),"paidUntil":\(json(paidUntil)),"paidByMe":\(paidByMe),
         "payerName":\(json(payerName)),
         "analysis":{"month":"2026-12","usedSec":1260,"limitSec":15000,"resetsAt":"2027-01-01T00:00:00+09:00"}}
        """
    }

    private func callJSON(id: String, state: String = "ANALYSIS_EXCLUDED", reason: String?) -> String {
        """
        {"callId":"\(id)","parentId":"mom","childId":"me","state":"\(state)","timeSlot":null,
         "startedAt":"2026-12-05T03:00:00Z","endedAt":"2026-12-05T03:30:00Z","durationSec":1800,
         "recorded":true,"recordingEnabled":true,"recordingDisabledReason":\(reason.map { "\"\($0)\"" } ?? "null"),
         "recordingDisabledMessage":null,"parentSpeechSec":600}
        """
    }

    private func serveFamily(_ fixture: TestEnvironment, calls: (Int, String), report: (Int, String)) {
        fixture.respond = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/members") {
                return (200, """
                {"members":[{"memberId":"mom","userId":"mom","name":"mom","relation":"MOTHER","status":"ACTIVE"}]}
                """)
            }
            if path.hasSuffix("/daily-questions") { return (200, #"{"source":"fixture","questions":[]}"#) }
            if path.hasSuffix("/baseline") { return (200, #"{"baselines":[]}"#) }
            if path == "/v1/parents/mom/calls" { return calls }
            if path == "/v1/parents/mom/reports" { return report }
            return (404, #"{"code":"NOT_FOUND","message":"없음"}"#)
        }
    }

    private func reportBody() -> String {
        """
        {"parentId":"mom","period":"WEEKLY","from":"2026-11-02","to":"2026-11-08","state":"READY",
         "disclaimer":"","promotedSignals":[],"acuteSignals":[],
         "conversationItems":{"activity":["산책했다고 이야기했어요."]},
         "repeatObservation":{"count":0,"callsWithRepeat":0,"label":""},"acousticTrends":[],
         "analyzedCallCount":1}
        """
    }
}

@MainActor
private final class FakeStore: SubscriptionStore {
    var identified: [String] = []
    var purchases = 0
    var restores = 0
    var price: String? = "₩13,000"
    var purchaseResult: Result<Bool, Error> = .success(true)

    func identify(userId: String) async throws {
        if identified.last != userId { identified.append(userId) }
    }

    func monthlyPrice() async throws -> String? { price }

    func purchaseMonthly() async throws -> Bool {
        purchases += 1
        return try purchaseResult.get()
    }

    func restore() async throws { restores += 1 }
}
