//
//  SectionHeaderView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        HStack(spacing: Spacing.x1) {
            AssetPlaceholder(size: IconSize.medium)
            Text(title)
                .subtitle_01(.gray1000)
        }
    }
}

#Preview {
    SectionHeaderView(title: "가족 전화하기")
        .padding()
}
