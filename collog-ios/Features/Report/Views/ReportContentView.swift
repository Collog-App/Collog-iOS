//
//  ReportContentView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ReportContentView: View {
    let report: WeeklyReport

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            if let noticeText = report.noticeText {
                noticeBanner(noticeText)
            }

            if report.state == .baselineCollecting {
                noticeBanner("아직 기준선을 모으는 중이에요. 통화가 쌓이면 변화를 보여드릴게요.")
            }

            StatTileRowView(stats: report.summaryStats)
                .cardSurface()

            ChangeSignalCardView(signals: report.changeSignals)

            VStack(alignment: .leading, spacing: Spacing.x4) {
                Text("음향 추세")
                    .caption_01_medium(.gray800)
                TrendChartView(series: report.acousticTrend)
            }
            .cardSurface()

            ConversationCardView(groups: report.conversationGroups)

            repeatCard

            Text(report.disclaimer)
                .caption_02_medium(.gray700)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.x1)
        }
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("되물으심")
                .caption_01_medium(.gray800)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(report.repeatObservation.countText)
                        .pretendard(.semiBold, 24, .gray900)
                    Text("회")
                        .body_02_medium(.gray800)
                }

                Spacer(minLength: Spacing.x1)

                Text(report.repeatObservation.perMinuteText)
                    .caption_02_medium(.gray700)
            }

            Text(report.repeatObservation.caption)
                .caption_02_medium(.gray700)
        }
        .cardSurface()
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.x2) {
            AssetPlaceholder(size: IconSize.small)
            Text(text)
                .caption_01_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.x3)
        .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))
    }
}

#Preview {
    ScrollView {
        ReportContentView(report: .sample)
            .padding(.horizontal, Spacing.x5)
    }
    .background(Color.gray50)
}
