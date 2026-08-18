//
//  SectionHeaderView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var trailingText: String?

    var body: some View {
        HStack(spacing: Spacing.x2) {
            AssetPlaceholder(size: IconSize.medium)

            Text(title)
                .pretendard(.semiBold, 18, .gray900)

            Spacer(minLength: Spacing.x2)

            if let trailingText {
                Text(trailingText)
                    .body_02_medium(.gray700)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeaderView(title: "가족 전화하기")
        SectionHeaderView(title: "우리 가족 건강", trailingText: "8월 3주")
    }
    .padding()
}
