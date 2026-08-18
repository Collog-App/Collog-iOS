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
        HStack(alignment: .center, spacing: Spacing.x3) {
            Text(entry.dateText)
                .subtitle_02(.gray900)

            Spacer(minLength: Spacing.x2)

            Text(entry.durationText)
                .caption_01_semibold(.gray800)
                .padding(.horizontal, Spacing.x3)
                .padding(.vertical, Spacing.x2)
                .background(Color.gray100, in: Capsule())
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x5)
        .padding(.bottom, Spacing.x3)
        .frame(maxWidth: .infinity)
        .background(Color.gray50)
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
            StatTileRowView(stats: entry.summaryStats)
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
            CallTimelineDateHeader(entry: .sample)
            CallTimelineCardView(entry: .sample)
                .padding(.horizontal, Spacing.x5)
        }
    }
    .background(Color.gray50)
}
