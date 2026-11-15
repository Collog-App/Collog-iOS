//
//  HealthLinkHintCardView.swift
//  collog-ios
//

import SwiftUI

/// 홈의 건강 앱 연결 안내(피그마 없음, 기존 카드 모양). 닫으면 다시 띄우지 않는다(HealthLink 가 기억).
struct HealthLinkHintCardView: View {
    let onConnect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.x2) {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                Text("건강 앱을 연결하면 가족이 수면·걸음 변화를 함께 볼 수 있어요")
                    .body_01_medium(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onConnect) {
                    Text("연결하기")
                        .body_02_semibold(.greenDark)
                        .padding(.horizontal, Spacing.x4)
                        .padding(.vertical, 10)
                        .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Icon(name: "xmark", size: IconSize.small, weight: .semibold, color: .gray600)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("안내 닫기")
            .padding(.top, -Spacing.x2)
            .padding(.trailing, -Spacing.x2)
        }
        .cardSurface()
    }
}

#Preview {
    HealthLinkHintCardView(onConnect: {}, onClose: {})
        .padding()
        .background(Color.gray50)
}
