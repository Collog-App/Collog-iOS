//
//  StatTileView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
    let caption: String
}

struct StatTileView: View {
    let stat: CallStat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text(stat.label)
                .caption_01_medium(.gray800)

            VStack(alignment: .leading, spacing: Spacing.x2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(stat.value)
                        .pretendard(.semiBold, 24, .gray900)
                    Text(stat.unit)
                        .body_02_medium(.gray800)
                }

                Text(stat.caption)
                    .caption_02_medium(.gray700)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTileRowView: View {
    let stats: [CallStat]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    DividerLine(axis: .vertical)
                        .padding(.horizontal, Spacing.x4)
                }

                StatTileView(stat: stat)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension CallStat {
    static let samples: [CallStat] = [
        CallStat(label: "통화 길이", value: "8", unit: "분", caption: "평소 12분"),
        CallStat(label: "되물으심", value: "2", unit: "회", caption: "평소 1회")
    ]
}

#Preview {
    StatTileRowView(stats: CallStat.samples)
        .padding()
        .background(Color.gray00)
}
