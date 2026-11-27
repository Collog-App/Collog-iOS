//
//  BillingStore.swift
//  collog-ios
//

import Foundation

/// 스토어 구독 연동(RevenueCat). 공개 SDK 키가 있을 때만 만든다. 시험은 가짜를 넣는다.
protocol SubscriptionStore {
    /// 로그인한 서버 사용자 ID 로 맞춘다. 처음이면 configure, 이미 configure 됐으면 logIn. logOut 은 부르지 않는다.
    func identify(userId: String) async throws
    /// 월 구독 상품의 스토어 가격 문자열(예 「₩13,000」). 상품이 없으면 nil.
    func monthlyPrice() async throws -> String?
    /// 월 구독을 산다. 사용자가 취소하면 false.
    func purchaseMonthly() async throws -> Bool
    func restore() async throws
}

/// 결제 화면 상태 줄. 서버 값(`EntitlementDTO`)으로만 정한다.
enum SubscriptionStatus: Equatable {
    /// 내가 결제했다. 다음 결제일 = 가족 유료 구독 만료.
    case paidByMe(nextBilling: Date?)
    /// 가족 중 다른 사람이 결제했다. 가족 안 중복 결제를 막으려고 구매 버튼을 숨긴다.
    case paidByFamily(payerName: String?)
    case trial(endsAt: Date)
    case none

    var allowsPurchase: Bool {
        switch self {
        case .trial, .none: true
        case .paidByMe, .paidByFamily: false
        }
    }
}

extension EntitlementDTO {
    var subscriptionStatus: SubscriptionStatus {
        if paidByMe == true { return .paidByMe(nextBilling: paidUntil) }
        if let payerName, !payerName.isEmpty { return .paidByFamily(payerName: payerName) }
        if source == "PAID" { return .paidByFamily(payerName: nil) }
        if source == "TRIAL", let trialEndsAt { return .trial(endsAt: trialEndsAt) }
        return .none
    }
}

/// 분석 분량을 다 써서 분석하지 않은 통화의 안내(결제 약속 2026-11-27).
enum AnalysisQuota {
    static let exceededReason = "ANALYSIS_QUOTA_EXCEEDED"
    static let freeText = "이번 달 무료 분석 시간(40분)을 다 써서 이 통화는 분석하지 않았어요."
    static let premiumText = "이번 달 분석 시간을 다 썼어요. 다음 달 1일에 다시 채워져요."

    static func text(isPremium: Bool) -> String { isPremium ? premiumText : freeText }
}

/// 결제(구독) 1차: 서버 요금제 값, 스토어 가격·구매·복원. 앱 전체에서 하나다(`AppEnvironment.billing`).
/// 둘러보기(게스트)에서는 서버도 스토어도 부르지 않는다.
@Observable
final class BillingStore {
    static let infoPlistKey = "RevenueCatAPIKey"
    static let preparingText = "결제를 준비하고 있어요"
    static let purchaseFailedText = "결제를 마치지 못했어요. 잠시 뒤 다시 시도해 주세요."
    static let restoreFailedText = "구매를 복원하지 못했어요. 잠시 뒤 다시 시도해 주세요."
    static let lockTitle = "주간 리포트와 타임라인은 프리미엄에서 볼 수 있어요"
    static let lockMessage = "통화가 쌓이면 부모님의 변화를 한 주, 한 달 단위로 모아 보여드려요."
    static let learnMoreTitle = "프리미엄 알아보기"

    private(set) var entitlement: EntitlementDTO?
    /// 「월 ₩13,000」처럼 스토어 가격 앞에 「월」을 붙인 글자. 못 불러왔으면 nil.
    private(set) var monthlyPrice: String?
    private(set) var isLoadingPrice = false
    private(set) var isWorking = false
    private(set) var errorText: String?
    @ObservationIgnored private let store: (any SubscriptionStore)?

    init(
        apiKey: String? = Bundle.main.object(forInfoDictionaryKey: BillingStore.infoPlistKey) as? String,
        makeStore: (String) -> any SubscriptionStore = { RevenueCatStore(apiKey: $0) }
    ) {
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // 빌드 설정이 비면 빈 값, 펼쳐지지 않았으면 「$(…)」 그대로 들어온다. 둘 다 키 없음으로 본다
        store = key.isEmpty || key.hasPrefix("$(") ? nil : makeStore(key)
    }

    /// 공개 SDK 키가 있어 구매·복원을 할 수 있다. 없으면 결제 화면은 「결제를 준비하고 있어요」만 보인다.
    var isStoreAvailable: Bool { store != nil }

    var locksReports: Bool { entitlement?.locksReports == true }

    /// 설정 「구독 관리」 줄 등 진입점. 결제가 꺼져 있거나 아직 모르면 숨긴다(지금과 같은 앱).
    var showsEntryPoints: Bool { entitlement?.billingEnabled == true }

    var status: SubscriptionStatus { entitlement?.subscriptionStatus ?? .none }

    var showsPurchaseButton: Bool { isStoreAvailable && monthlyPrice != nil && status.allowsPurchase }

    /// 계정이 바뀌거나 로그아웃하면 지난 사람의 요금제를 남기지 않는다.
    func reset() {
        entitlement = nil
        errorText = nil
    }

    /// 로그인 뒤 본 화면에 들어올 때: 스토어에 사용자를 알리고 서버 값을 읽는다.
    func start(using environment: AppEnvironment) async {
        guard let userId = signedInUserId(environment) else { return }
        if let store { try? await store.identify(userId: userId) }
        await refresh(using: environment)
    }

    /// 서버 값을 다시 읽는다(앱 시작·앞으로 올 때). 실패하면 가진 값을 그대로 둔다.
    func refresh(using environment: AppEnvironment) async {
        guard let userId = signedInUserId(environment) else { return }
        let api = environment.api
        guard let value = try? await api.entitlement(), environment.session.user?.id == userId else { return }
        entitlement = value
    }

    /// 결제 화면을 열 때 스토어 가격을 한 번 불러온다.
    func loadPrice(using environment: AppEnvironment) async {
        guard let store, monthlyPrice == nil, !isLoadingPrice,
              let userId = signedInUserId(environment) else { return }
        isLoadingPrice = true
        defer { isLoadingPrice = false }
        try? await store.identify(userId: userId)
        if let price = try? await store.monthlyPrice() {
            monthlyPrice = "월 \(price)"
        }
    }

    /// 구매 → 서버에 다시 읽게 함 → 화면 갱신. 사용자가 취소하면 아무 안내 없이 그대로 둔다.
    func purchase(using environment: AppEnvironment) async {
        guard let store, !isWorking, let userId = signedInUserId(environment) else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await store.identify(userId: userId)
            guard try await store.purchaseMonthly() else { return }
        } catch {
            errorText = Self.purchaseFailedText
            return
        }
        await refreshAfterStoreChange(using: environment, userId: userId)
    }

    func restore(using environment: AppEnvironment) async {
        guard let store, !isWorking, let userId = signedInUserId(environment) else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await store.identify(userId: userId)
            try await store.restore()
        } catch {
            errorText = Self.restoreFailedText
            return
        }
        await refreshAfterStoreChange(using: environment, userId: userId)
    }

    /// 구매·복원 직후는 `POST …/refresh`. 그것이 실패하면 저장된 값이라도 다시 읽는다.
    private func refreshAfterStoreChange(using environment: AppEnvironment, userId: String) async {
        let api = environment.api
        var value = try? await api.refreshEntitlement()
        if value == nil { value = try? await api.entitlement() }
        guard let value, environment.session.user?.id == userId else { return }
        entitlement = value
    }

    private func signedInUserId(_ environment: AppEnvironment) -> String? {
        guard !environment.settings.isGuestMode, environment.session.isAuthenticated else { return nil }
        return environment.session.user?.id
    }

    // MARK: - 표시

    /// 「M월 d일」(한국 시간).
    static func dayText(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    /// 결제 화면 상태 줄. 상태가 없으면 nil.
    static func statusText(_ status: SubscriptionStatus) -> String? {
        switch status {
        case let .paidByMe(nextBilling):
            nextBilling.map { "프리미엄 이용 중 · 다음 결제 \(dayText($0))" } ?? "프리미엄 이용 중"
        case let .paidByFamily(payerName):
            payerName.map { "\($0)님 덕분에 가족 모두 프리미엄을 쓰고 있어요" } ?? "가족 모두 프리미엄을 쓰고 있어요"
        case let .trial(endsAt):
            "무료 체험 중 · \(dayText(endsAt))까지"
        case .none:
            nil
        }
    }

    /// 설정 「구독 관리」 줄의 지금 요금제.
    static func planText(_ entitlement: EntitlementDTO) -> String {
        guard entitlement.isPremium else { return "무료" }
        if entitlement.source == "TRIAL", let trialEndsAt = entitlement.trialEndsAt {
            return "프리미엄 · 무료 체험 \(dayText(trialEndsAt))까지"
        }
        return "프리미엄"
    }

    /// 설정 「구독 관리」 줄의 이번 달 분석(「12분 / 40분」).
    static func usageText(_ analysis: EntitlementDTO.Analysis) -> String {
        "\(analysis.usedSec / 60)분 / \(analysis.limitSec / 60)분"
    }
}
