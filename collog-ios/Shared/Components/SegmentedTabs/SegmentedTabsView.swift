//
//  SegmentedTabsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct SegmentedTabsView: View {
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    selection = index
                } label: {
                    Text(title)
                        .body_02_semibold(selection == index ? .gray900 : .gray600)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.btnLarge, style: .continuous)
                                .fill(selection == index ? Color.gray00 : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.x1)
        .frame(height: 48)
        .background(Color.gray300, in: RoundedRectangle(cornerRadius: Radius.btnLarge, style: .continuous))
    }
}

#Preview {
    @Previewable @State var selection = 0

    SegmentedTabsView(titles: ["질문 미리보기", "전화 로그"], selection: $selection)
        .padding()
}
