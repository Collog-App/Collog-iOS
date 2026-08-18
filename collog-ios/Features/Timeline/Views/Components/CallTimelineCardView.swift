//
//  CallTimelineCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallTimelineCardView: View {
    let entry: CallTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack {
                Text(entry.dateText)
                    .body_01_semibold(.gray900)
                Spacer(minLength: Spacing.x2)
                Text(entry.durationText)
                    .body_02_medium(.gray800)
            }
            .padding(.vertical, Spacing.x2)

            StatTileRowView(stats: entry.summaryStats)
                .cardSurface()

            storyCard

            if !entry.gauges.isEmpty {
                RangeGaugeRowView(gauges: entry.gauges)
                    .cardSurface()
            }

            if !entry.counts.isEmpty {
                StatTileRowView(stats: entry.counts, layout: .stacked)
                    .cardSurface()
            }
        }
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("나눈 이야기")
                .caption_01_medium(.gray800)

            Text(entry.story)
                .body_03_medium(.gray900)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.keywords.isEmpty {
                DividerLine()

                KeywordTimelineView(marks: entry.keywords)
            }
        }
        .cardSurface()
    }
}

#Preview {
    ScrollView {
        CallTimelineCardView(entry: .sample)
            .padding(.horizontal, Spacing.x5)
    }
    .background(Color.gray50)
}
