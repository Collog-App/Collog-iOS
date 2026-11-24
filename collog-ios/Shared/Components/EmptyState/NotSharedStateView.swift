//
//  NotSharedStateView.swift
//  collog-ios
//

import SwiftUI

/// 가족이 「가족 공유 데이터 범위」에서 나에게 공유를 꺼 서버가 막은(403) 리포트·타임라인.
/// 불러오지 못한 것이 아니라 볼 수 없는 항목이라 「다시 시도」를 두지 않는다.
struct NotSharedStateView: View {
    static let title = "이 가족이 공유하지 않은 항목이에요"
    static let message = "가족이 설정의 「가족 공유 데이터 범위」에서 공유를 켜면 볼 수 있어요."

    var body: some View {
        EmptyStateView(symbol: "eye.slash", title: Self.title, message: Self.message)
    }
}

#Preview {
    NotSharedStateView()
        .background(Color.gray50)
}
