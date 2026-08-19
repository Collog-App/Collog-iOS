//
//  CallTimelineCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallTimelineDateHeader: View {
    let entry: CallTimelineEntry

    var body: some View {
        Text(compactDateText)
            .body_01_semibold(.gray900)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactDateText: String {
        guard let monthEnd = entry.dateText.range(of: "월 ") else { return entry.dateText }
        return String(entry.dateText[monthEnd.upperBound...])
    }
}

struct CallTimelineRail: View {
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.gray800)
                .frame(width: 12, height: 3)
                .padding(.top, 9)

            Rectangle()
                .fill(isLast ? Color.gray300.opacity(0.7) : Color.gray300)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct CallTimelineCardView: View {
    let entry: CallTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            metricRow(entry.summaryStats)

            DividerLine()

            Text(entry.story)
                .body_02_medium(.gray900)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.keywords.isEmpty {
                KeywordTimelineView(marks: entry.keywords)
                    .padding(.top, Spacing.x1)
            }

            if !entry.gauges.isEmpty {
                DividerLine()
                RangeGaugeRowView(gauges: entry.gauges)
            }

            if !entry.counts.isEmpty {
                DividerLine()
                countRow
            }
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        }
    }

    private func metricRow(_ stats: [CallStat]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    DividerLine(axis: .vertical)
                        .padding(.horizontal, Spacing.x4)
                }

                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(stat.label)
                        .caption_01_medium(.gray700)

                    HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                        Text(stat.value)
                            .subtitle_01(.gray900)

                        Text(stat.unit)
                            .caption_01_medium(.gray800)

                        if let note = stat.note {
                            Text(note.text)
                                .caption_01_medium(.gray700)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var countRow: some View {
        HStack(spacing: Spacing.x4) {
            ForEach(entry.counts) { stat in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                    Text(stat.label)
                        .caption_01_medium(.gray700)

                    Text("\(stat.value)\(stat.unit)")
                        .body_02_semibold(.gray900)
                }

                if stat.id != entry.counts.last?.id {
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.x3) {
                CallTimelineRail(isLast: true)

                VStack(spacing: Spacing.x3) {
                    CallTimelineDateHeader(entry: .sample)
                    CallTimelineCardView(entry: .sample)
                }
            }
            .padding(.horizontal, Spacing.x5)
        }
    }
    .background(Color.gray50)
}
