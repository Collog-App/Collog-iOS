//
//  PaywallView.swift
//  collog-ios
//

import StoreKit
import SwiftUI
import UIKit

/// 결제 화면(결제 약속 2026-11-27 §3, RevenueCat Paywalls UI 안 씀). 잠금 화면·분량 초과 안내·설정 「구독 관리」가 시트로 연다.
/// App Store 3.1.2: 가격·기간·자동 갱신·이용약관·개인정보처리방침·구매 복원을 구매 버튼과 같은 화면에 둔다.
struct PaywallView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    static let title = "콜록 프리미엄"
    static let benefits = [
        "주간·월간 리포트로 부모님 변화를 한눈에",
        "증상 타임라인으로 지난 통화를 날짜별로",
        "통화 분석 월 250분 (무료는 40분)"
    ]
    static let renewalText = "매월 자동으로 결제되고, 언제든 해지할 수 있어요."
    static let purchaseTitle = "프리미엄 시작하기"
    static let termsURL = URL(string: "https://privacy.collog.live/terms.html")!
    static let privacyURL = URL(string: "https://privacy.collog.live/")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private var billing: BillingStore { environment.billing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x5) {
                    Text(Self.title)
                        .headline_02(.gray900)

                    // 가족이 결제했을 때의 상태 글은 구매 버튼 자리에 보인다
                    if billing.status.allowsPurchase || isPaidByMe,
                       let status = BillingStore.statusText(billing.status) {
                        statusBadge(status)
                    }

                    benefitList

                    if billing.status.allowsPurchase {
                        priceSection
                    }

                    actionSection

                    if let notice = billing.noticeText {
                        Text(notice)
                            .body_02_medium(.gray800)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error = billing.errorText {
                        Text(error)
                            .body_02_medium(.red500)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    links
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.x5)
                .padding(.top, Spacing.x4)
                .padding(.bottom, Spacing.x8)
            }
            .background(Color.gray50)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            await billing.refresh(using: environment)
            await billing.loadPrice(using: environment)
        }
    }

    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .body_02_semibold(.greenDark)
            .padding(.horizontal, Spacing.x3)
            .padding(.vertical, Spacing.x2)
            .background(Color.greenLight, in: Capsule())
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            ForEach(Self.benefits, id: \.self) { benefit in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                    Icon(name: "checkmark", size: IconSize.small, weight: .bold, color: .greenNormal)
                    Text(benefit)
                        .body_01_medium(.gray900)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var priceSection: some View {
        if let price = billing.monthlyPrice {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(price)
                    .subtitle_01(.gray900)
                Text(Self.renewalText)
                    .body_02_medium(.gray700)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if billing.isLoadingPrice {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else {
            // 공개 SDK 키가 없거나 스토어 상품을 받지 못했으면 구매 버튼 없이 이것만 보인다
            Text(BillingStore.preparingText)
                .body_01_medium(.gray700)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch billing.status {
        case .paidByMe:
            secondaryButton("구독 관리·해지", action: manageSubscriptions)
        case .paidByFamily:
            if let text = BillingStore.statusText(billing.status) {
                Text(text)
                    .body_01_semibold(.greenDark)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.x4)
                    .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
            }
        case .trial, .none:
            if billing.showsPurchaseButton {
                Button {
                    Haptics.press()
                    Task { await billing.purchase(using: environment) }
                } label: {
                    ZStack {
                        if billing.isWorking {
                            ProgressView().tint(.gray00)
                        } else {
                            Text(Self.purchaseTitle)
                                .body_01_semibold(.gray00)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(billing.isWorking)
            }
        }
    }

    private var links: some View {
        VStack(spacing: Spacing.x3) {
            HStack(spacing: Spacing.x4) {
                if billing.isStoreAvailable {
                    linkButton("구매 복원") { Task { await billing.restore(using: environment) } }
                        .disabled(billing.isWorking)
                }
                // 내가 결제했으면 위에 「구독 관리·해지」 버튼이 따로 있다
                if !isPaidByMe {
                    linkButton("구독 관리·해지", action: manageSubscriptions)
                }
            }
            HStack(spacing: Spacing.x4) {
                linkButton("이용약관") { openURL(Self.termsURL) }
                linkButton("개인정보처리방침") { openURL(Self.privacyURL) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.x2)
    }

    private var isPaidByMe: Bool {
        if case .paidByMe = billing.status { return true }
        return false
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .body_03_medium(.gray700)
                .underline()
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .body_01_semibold(.greenDark)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// App Store 구독 관리 창. 띄우지 못하면 App Store 구독 화면 주소를 연다.
    private func manageSubscriptions() {
        Task {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            if let scene, (try? await AppStore.showManageSubscriptions(in: scene)) != nil { return }
            openURL(Self.manageSubscriptionsURL)
        }
    }
}

#Preview {
    let environment = AppEnvironment()
    PaywallView()
        .environment(environment)
}
