//
//  BillingStore.swift
//  collog-ios
//

import Foundation

/// 스토어 구독 연동(RevenueCat). 공개 SDK 키가 있을 때만 만든다. 시험은 가짜를 넣는다.
protocol SubscriptionStore {
    /// 로그인한 서버 사용자 ID 로 맞춘다. 처음이면 configure, 이미 configure 됐으면 logIn. logOut 은 부르지 않는다.
    func identify(userId: String) async throws
    /// 월 구독 상품의 스토어 가격. 상품이 없으면 nil.
    func monthlyPrice() async throws -> StorePrice?
    /// 월 구독을 산다. 분류할 수 없는 실패만 던진다.
    func purchaseMonthly() async throws -> PurchaseOutcome
    /// 구매를 복원한다. 복원 결과에 활성 `premium` 이 있으면 true.
    func restore() async throws -> Bool
}

enum PurchaseOutcome: Equatable {
    case purchased
    /// 사용자가 취소했다(안내 없이 그대로 둔다).
    case cancelled
    /// 결제 승인(보호자 승인·추가 인증 등)을 기다린다.
    case pending
    /// 이 Apple ID 에 이미 활성 구독이 있다(복원하면 된다).
    case alreadyPurchased
}

/// 스토어 상품 가격. KRW 는 숫자로 「13,000원」을 만들고(스토어 문자열은 「₩13,000」), 다른 통화는 스토어 문자열 그대로 쓴다.
struct StorePrice: Equatable {
    let amount: Decimal
    let currencyCode: String?
    let localizedString: String
}

/// 결제 화면 상태 줄. 서버 값(`EntitlementDTO`)으로만 정한다.
enum SubscriptionStatus: Equatable {
    /// 내가 결제했다. `until` = 가족 유료 구독 만료, `willRenew` = 그 구독이 자동 갱신 중인가(해지해 뒀으면 false).
    case paidByMe(until: Date?, willRenew: Bool)
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
        if paidByMe == true { return .paidByMe(until: paidUntil, willRenew: willRenew == true) }
        if let payerName, !payerName.isEmpty { return .paidByFamily(payerName: payerName) }
        if source == "PAID" { return .paidByFamily(payerName: nil) }
        if source == "TRIAL", let trialEndsAt { return .trial(endsAt: trialEndsAt) }
        return .none
    }
}

/// 분석 분량을 다 써서 분석하지 않은 통화의 안내(결제 약속 2026-11-27).
enum AnalysisQuota {
    static let exceededReason = "ANALYSIS_QUOTA_EXCEEDED"
    static let premiumText = "이번 달 분석 시간을 다 썼어요. 다음 달 1일에 다시 채워져요."
    /// 요금제를 모를 때(서버 `recordingDisabledMessage` 와 같은 문구).
    static let neutralText = "이번 달 분석 시간을 다 써서 이 통화는 분석하지 않았어요."

    /// 무료 한도는 서버 `analysis.limitSec` 를 따른다(없으면 40분).
    static func freeText(limitSec: Int?) -> String {
        "이번 달 무료 분석 시간(\((limitSec ?? 2400) / 60)분)을 다 써서 이 통화는 분석하지 않았어요."
    }

    static func text(for entitlement: EntitlementDTO?) -> String {
        guard let entitlement else { return neutralText }
        return entitlement.isPremium ? premiumText : freeText(limitSec: entitlement.analysis?.limitSec)
    }
}

/// 결제(구독) 1차: 서버 요금제 값, 스토어 가격·구매·복원. 앱 전체에서 하나다(`AppEnvironment.billing`).
/// 둘러보기(게스트)에서는 서버도 스토어도 부르지 않는다. 스토어 SDK 는 서버가 `billingEnabled=true` 라고 할 때만 켠다
/// (결제가 꺼져 있으면 키가 있는 빌드라도 RevenueCat 에 아무것도 보내지 않는다).
@Observable
final class BillingStore {
    static let infoPlistKey = "RevenueCatAPIKey"
    static let preparingText = "결제를 준비하고 있어요"
    static let purchaseFailedText = "결제를 마치지 못했어요. 잠시 뒤 다시 시도해 주세요."
    static let restoreFailedText = "구매를 복원하지 못했어요. 잠시 뒤 다시 시도해 주세요."
    static let pendingText = "결제는 완료됐어요. 반영까지 잠시 걸릴 수 있어요."
    static let nothingToRestoreText = "복원할 구매가 없어요."
    static let approvalPendingText = "결제 승인을 기다리고 있어요. 승인되면 자동으로 반영돼요."
    static let alreadyPurchasedText = "이미 구매한 구독이 있어요. 구매 복원을 눌러 주세요."
    static let lockTitle = "주간 리포트와 타임라인은 프리미엄에서 볼 수 있어요"
    static let lockMessage = "통화가 쌓이면 부모님의 변화를 한 주, 한 달 단위로 모아 보여드려요."
    static let learnMoreTitle = "프리미엄 알아보기"

    private(set) var entitlement: EntitlementDTO?
    /// 「월 13,000원」. 못 불러왔으면 nil.
    private(set) var monthlyPrice: String?
    private(set) var isLoadingPrice = false
    /// 가격을 받으려 했지만 못 받았다(또는 스토어를 쓸 수 없다). 그 전까지 결제 화면은 불러오는 중으로 보인다.
    private(set) var priceUnavailable = false
    private(set) var isWorking = false
    private(set) var errorText: String?
    /// 오류가 아닌 안내(반영 중·복원할 구매 없음·승인 대기·이미 구매함).
    private(set) var noticeText: String?
    @ObservationIgnored private let store: (any SubscriptionStore)?
    /// 요청 순서: 지금 값보다 나중에 출발한 요청의 응답만 적용한다(느린 GET 이 방금 받은 PAID 를 덮지 않게).
    @ObservationIgnored private var lastRequest = 0
    @ObservationIgnored private var appliedRequest = 0
    /// 지금 값을 읽을 때의 가족. 가족에 합류하거나 나가면 요금제가 달라진다.
    @ObservationIgnored private var fetchedFamilyId: String?

    init(
        apiKey: String? = Bundle.main.object(forInfoDictionaryKey: BillingStore.infoPlistKey) as? String,
        makeStore: (String) -> any SubscriptionStore = { RevenueCatStore(apiKey: $0) }
    ) {
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // App Store 공개 키(appl_)만 쓴다. 빈 값·펼쳐지지 않은 「$(…)」·Test Store 키(출시판에서 SDK 가 일부러 멈춘다) 등은 키 없음
        store = key.hasPrefix("appl_") ? makeStore(key) : nil
    }

    /// 공개 SDK 키가 있어 구매·복원을 할 수 있다. 없으면 결제 화면은 「결제를 준비하고 있어요」만 보인다.
    var isStoreAvailable: Bool { store != nil }

    var locksReports: Bool { entitlement?.locksReports == true }

    /// 설정 「구독 관리」 줄 등 진입점. 결제가 꺼져 있거나 아직 모르면 숨긴다(지금과 같은 앱).
    var showsEntryPoints: Bool { entitlement?.billingEnabled == true }

    var status: SubscriptionStatus { entitlement?.subscriptionStatus ?? .none }

    /// 「프리미엄 알아보기」 같은 진입점: 결제가 켜져 있고 프리미엄이 아닐 때만. 요금제를 모르면 두지 않는다.
    var offersPremium: Bool { entitlement?.billingEnabled == true && entitlement?.isPremium == false }

    /// 결제 화면 가격 자리가 불러오는 중인지(처음 열 때부터).
    var isPriceLoading: Bool { isStoreAvailable && monthlyPrice == nil && !priceUnavailable }

    var showsPurchaseButton: Bool { isStoreAvailable && monthlyPrice != nil && status.allowsPurchase }

    /// 계정이 바뀌거나 로그아웃하면 지난 사람의 요금제를 남기지 않는다.
    func reset() {
        entitlement = nil
        errorText = nil
        noticeText = nil
        fetchedFamilyId = nil
        // 지난 계정을 위해 출발한 요청의 응답은 적용하지 않는다
        lastRequest += 1
        appliedRequest = lastRequest
    }

    /// 서버 값을 다시 읽는다(본 화면 진입·앞으로 올 때·결제 화면을 열 때). 실패하면 가진 값을 그대로 둔다.
    /// 결제가 켜져 있으면 스토어에 로그인한 서버 사용자를 알린다(처음이면 configure, 아니면 logIn).
    func refresh(using environment: AppEnvironment) async {
        guard let userId = signedInUserId(environment) else { return }
        let api = environment.api
        let request = beginRequest(environment)
        guard let value = try? await api.entitlement(), environment.session.user?.id == userId else { return }
        apply(value, request: request)
        if entitlement?.source == "PAID" { noticeText = nil }
        if let store = activeStore { try? await store.identify(userId: userId) }
    }

    /// 가족에 합류하거나 나가거나 내보내져 가족이 바뀌었으면 요금제를 다시 읽는다.
    func refreshIfFamilyChanged(using environment: AppEnvironment) async {
        guard entitlement != nil, environment.session.familyId != fetchedFamilyId else { return }
        await refresh(using: environment)
    }

    /// 결제 화면을 열 때: 지난번 오류·안내를 지우고 가격을 다시 불러오는 중으로 둔다.
    func preparePaywall() {
        errorText = nil
        noticeText = nil
        priceUnavailable = false
    }

    /// 결제 화면을 열 때 스토어 가격을 한 번 불러온다.
    func loadPrice(using environment: AppEnvironment) async {
        guard monthlyPrice == nil, !isLoadingPrice, let userId = signedInUserId(environment) else { return }
        guard let store = activeStore else {
            priceUnavailable = true
            return
        }
        isLoadingPrice = true
        defer { isLoadingPrice = false }
        try? await store.identify(userId: userId)
        if let price = try? await store.monthlyPrice() {
            monthlyPrice = Self.priceText(price)
        } else {
            priceUnavailable = true
        }
    }

    /// 구매 → 서버에 다시 읽게 함 → 화면 갱신. 사용자가 취소하면 아무 안내 없이 그대로 둔다.
    func purchase(using environment: AppEnvironment) async {
        guard let store = activeStore, !isWorking, let userId = signedInUserId(environment) else { return }
        isWorking = true
        errorText = nil
        noticeText = nil
        defer { isWorking = false }
        let outcome: PurchaseOutcome
        do {
            try await store.identify(userId: userId)
            outcome = try await store.purchaseMonthly()
        } catch {
            // 실패로 보여도 결제가 됐을 수 있어 서버 값을 한 번 확인한다
            let request = beginRequest(environment)
            if let value = try? await environment.api.entitlement(), environment.session.user?.id == userId {
                apply(value, request: request)
            }
            if entitlement?.source != "PAID" { errorText = Self.purchaseFailedText }
            return
        }
        switch outcome {
        case .cancelled: return
        case .pending: noticeText = Self.approvalPendingText
        case .alreadyPurchased: noticeText = Self.alreadyPurchasedText
        case .purchased: await refreshAfterStoreChange(using: environment, userId: userId)
        }
    }

    /// 복원 결과에 활성 `premium` 이 없으면 「복원할 구매가 없어요.」, 있으면 서버에 다시 읽게 한다.
    /// 잠금·요금제 판단은 여전히 서버 값만 쓴다.
    func restore(using environment: AppEnvironment) async {
        guard let store = activeStore, !isWorking, let userId = signedInUserId(environment) else { return }
        isWorking = true
        errorText = nil
        noticeText = nil
        defer { isWorking = false }
        let restored: Bool
        do {
            try await store.identify(userId: userId)
            restored = try await store.restore()
        } catch {
            errorText = Self.restoreFailedText
            return
        }
        guard restored else {
            noticeText = Self.nothingToRestoreText
            return
        }
        await refreshAfterStoreChange(using: environment, userId: userId)
    }

    /// 구매·복원 직후는 `POST …/refresh`. 서버가 스토어 확인에 실패했거나(502 `UPSTREAM_ERROR`) 연결이 끊기면
    /// 저장된 값을 한 번 더 읽는다. 그래도(또는 refresh 가 200 이어도) 아직 유료가 아니면 반영 중이라고 알린다(웹훅이 곧 반영).
    private func refreshAfterStoreChange(using environment: AppEnvironment, userId: String) async {
        let api = environment.api
        var request = beginRequest(environment)
        var value = try? await api.refreshEntitlement()
        if value == nil {
            request = beginRequest(environment)
            value = try? await api.entitlement()
        }
        guard environment.session.user?.id == userId else { return }
        if let value { apply(value, request: request) }
        if entitlement?.source != "PAID" { noticeText = Self.pendingText }
    }

    /// 요청을 시작할 때 번호를 받는다. 그때의 가족도 같이 기억한다.
    func beginRequest(_ environment: AppEnvironment) -> (id: Int, familyId: String?) {
        lastRequest += 1
        return (lastRequest, environment.session.familyId)
    }

    /// 지금 값보다 나중에 출발한 요청의 응답만 적용한다. 적용했으면 true.
    @discardableResult
    func apply(_ value: EntitlementDTO, request: (id: Int, familyId: String?)) -> Bool {
        guard request.id > appliedRequest else { return false }
        appliedRequest = request.id
        entitlement = value
        fetchedFamilyId = request.familyId
        return true
    }

    /// 키가 있고 서버가 결제를 켰을 때만 스토어를 쓴다.
    private var activeStore: (any SubscriptionStore)? {
        entitlement?.billingEnabled == true ? store : nil
    }

    private func signedInUserId(_ environment: AppEnvironment) -> String? {
        guard !environment.settings.isGuestMode, environment.session.isAuthenticated else { return nil }
        return environment.session.user?.id
    }

    // MARK: - 표시

    /// 「M월 d일」(한국 시간). 「다음 결제 M월 d일」에 쓴다.
    static func dayText(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// 「M월 d일까지」의 날짜: 끝 시각 1초 전의 한국 날짜(마지막으로 쓸 수 있는 날).
    static func untilText(_ date: Date) -> String {
        dayText(date.addingTimeInterval(-1))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    /// 결제 화면 가격 줄. KRW 는 「월 13,000원」, 다른 통화는 「월 」 + 스토어 가격 문자열.
    static func priceText(_ price: StorePrice) -> String {
        guard price.currencyCode == "KRW", let amount = wonFormatter.string(from: price.amount as NSDecimalNumber) else {
            return "월 \(price.localizedString)"
        }
        return "월 \(amount)원"
    }

    private static let wonFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// 결제 화면 상태 줄. 상태가 없으면 nil.
    static func statusText(_ status: SubscriptionStatus) -> String? {
        switch status {
        case let .paidByMe(until, willRenew):
            switch (until, willRenew) {
            case let (until?, true): "프리미엄 이용 중 · 다음 결제 \(dayText(until))"
            case let (until?, false): "프리미엄 이용 중 · \(untilText(until))까지"
            case (nil, _): "프리미엄 이용 중"
            }
        case let .paidByFamily(payerName):
            payerName.map { "\($0)님 덕분에 가족 모두 프리미엄을 쓰고 있어요" } ?? "가족 모두 프리미엄을 쓰고 있어요"
        case let .trial(endsAt):
            "무료 체험 중 · \(untilText(endsAt))까지"
        case .none:
            nil
        }
    }

    /// 설정 「구독 관리」 줄의 지금 요금제.
    static func planText(_ entitlement: EntitlementDTO) -> String {
        guard entitlement.isPremium else { return "무료" }
        if entitlement.source == "TRIAL", let trialEndsAt = entitlement.trialEndsAt {
            return "프리미엄 · 무료 체험 \(untilText(trialEndsAt))까지"
        }
        return "프리미엄"
    }

    /// 설정 「구독 관리」 줄의 이번 달 분석(「12분 / 40분」).
    static func usageText(_ analysis: EntitlementDTO.Analysis) -> String {
        "\(analysis.usedSec / 60)분 / \(analysis.limitSec / 60)분"
    }
}
