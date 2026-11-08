//
//  SafetyNoticeCardView.swift
//  collog-ios
//

import SwiftUI

/// 응급 안내(2026-11-08 가드레일): 서버가 고정 문구로 남긴 안내를 경고색 카드로 보인다. 아이콘 없이 문구만.
/// 리포트 맨 위와 그 통화의 분석 위에 둔다. `caption`은 어느 통화인지(「11월 7일 통화」).
struct SafetyNoticeCardView: View {
    let text: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(text)
                .body_01_semibold(.red700)
                .fixedSize(horizontal: false, vertical: true)

            if let caption {
                Text(caption)
                    .caption_01_regular(.gray800)
            }
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red100, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.red500.opacity(0.45), lineWidth: 1)
        }
    }
}

#Preview {
    SafetyNoticeCardView(
        text: "통화 중에 바로 확인이 필요할 수 있는 말씀이 있었어요. 지금 상태를 직접 확인하고, 필요하면 119나 가까운 병원에 연락하세요.",
        caption: "11월 7일 통화"
    )
    .padding()
    .background(Color.gray50)
}
