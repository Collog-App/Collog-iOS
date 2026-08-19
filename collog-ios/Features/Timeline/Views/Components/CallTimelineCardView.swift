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
        HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
            Text(entry.dateText)
                .body_01_semibold(.gray900)

            Spacer(minLength: Spacing.x2)

            Text(entry.durationText)
                .caption_01_medium(.gray700)
        }
        .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: 0) {
            summarySection

            sectionDivider

            storySection

            if !entry.gauges.isEmpty {
                sectionDivider
                gaugeSection
            }

            if !entry.counts.isEmpty {
                sectionDivider
                countSection
            }
        }
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatTileRowView(stats: entry.summaryStats, layout: .stacked)
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green100)
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("나눈 이야기")
                .body_02_semibold(.gray900)

            Text(entry.story)
                .body_03_medium(.gray900)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.keywords.isEmpty {
                DividerLine()

                KeywordTimelineView(marks: entry.keywords)
            }
        }
        .padding(Spacing.x5)
    }

    private var gaugeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("음성 특징")
                .body_02_semibold(.gray900)

            RangeGaugeRowView(gauges: entry.gauges)
        }
        .padding(Spacing.x5)
    }

    private var countSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("관찰 기록")
                .body_02_semibold(.gray900)

            StatTileRowView(stats: entry.counts, layout: .stacked)
        }
        .padding(Spacing.x5)
    }

    private var sectionDivider: some View {
        DividerLine()
            .padding(.horizontal, Spacing.x5)
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
