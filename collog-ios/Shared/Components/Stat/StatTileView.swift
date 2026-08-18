//
//  StatTileView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

enum StatTrend {
    case up
    case down
    case flat

    var color: Color { .gray700 }
}

struct StatNote {
    let text: String
    var trend: StatTrend = .flat
}

struct CallStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
    let note: StatNote?
}

enum StatTileLayout {
    case inline
    case stacked
}

struct StatTileView: View {
    let stat: CallStat
    var layout: StatTileLayout = .inline

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text(stat.label)
                .caption_01_medium(.gray800)

            if layout == .inline {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                    valueText
                    Spacer(minLength: Spacing.x1)
                    noteText
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    valueText
                    noteText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(stat.value)
                .pretendard(.semiBold, 24, .gray900)
            Text(stat.unit)
                .body_02_medium(.gray800)
        }
    }

    @ViewBuilder
    private var noteText: some View {
        if let note = stat.note {
            HStack(spacing: 1) {
                if note.trend != .flat {
                    Icon(
                        name: note.trend == .up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
                        size: 9,
                        color: note.trend.color
                    )
                }
                Text(note.text)
                    .caption_01_medium(note.trend == .flat ? .gray700 : note.trend.color)
            }
        }
    }
}

struct StatTileRowView: View {
    let stats: [CallStat]
    var layout: StatTileLayout = .inline

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    DividerLine(axis: .vertical)
                        .padding(.horizontal, Spacing.x4)
                }

                StatTileView(stat: stat, layout: layout)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension CallStat {
    static let samples: [CallStat] = [
        CallStat(label: "통화 길이", value: "8", unit: "분", note: StatNote(text: "평소 12분")),
        CallStat(label: "말씀 속도", value: "210", unit: "음절/분", note: StatNote(text: "1.32%", trend: .up))
    ]
}

#Preview {
    VStack(spacing: 24) {
        StatTileRowView(stats: CallStat.samples)
        StatTileRowView(stats: CallTimelineEntry.sample.counts, layout: .stacked)
    }
    .padding()
    .background(Color.gray00)
}
