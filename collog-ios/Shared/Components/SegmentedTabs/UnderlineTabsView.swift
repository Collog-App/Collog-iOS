//
//  UnderlineTabsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct UnderlineTabsView: View {
    let titles: [String]
    @Binding var selection: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: Spacing.x3) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    selection = index
                } label: {
                    Text(title)
                        .pretendard(.semiBold, size, selection == index ? .gray900 : .gray700)
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selection == index ? Color.gray900 : Color.clear)
                                .frame(height: 1.5)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = 1

    UnderlineTabsView(titles: ["리포트", "타임라인"], selection: $selection, size: 20)
        .padding()
}
