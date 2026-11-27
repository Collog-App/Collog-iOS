//
//  PremiumLockedStateView.swift
//  collog-ios
//

import SwiftUI

/// 무료 요금제의 리포트·타임라인 탭(결제 약속 2026-11-27). 「공유 꺼짐」(403)과는 다른 화면이다.
struct PremiumLockedStateView: View {
    let onLearnMore: () -> Void

    var body: some View {
        EmptyStateView(
            symbol: "lock",
            title: BillingStore.lockTitle,
            message: BillingStore.lockMessage,
            actionTitle: BillingStore.learnMoreTitle,
            action: onLearnMore
        )
    }
}

#Preview {
    PremiumLockedStateView {}
        .background(Color.gray50)
}
