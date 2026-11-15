//
//  LifeRecordCardView.swift
//  collog-ios
//

import SwiftUI

/// 리포트 「생활 기록」(피그마 없음, 기존 카드 모양): 최근 7일 수면·걸음 막대와 최근 심박·혈압·혈당.
/// 연결 안 된 사람이면 안내만, 내 리포트면 `onConnect`로 연결 흐름을 연다.
struct LifeRecordCardView: View {
    let record: LifeRecord
    var onConnect: (() -> Void)?

    private let barAreaHeight: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack {
                Text("생활 기록")
                    .caption_01_medium(.gray800)
                Spacer(minLength: Spacing.x2)
                if record.connected {
                    Text(record.rangeText)
                        .caption_01_medium(.gray700)
                }
            }

            if record.connected {
                connectedContent
            } else {
                Text("아직 건강 앱이 연결되지 않았어요")
                    .body_02_medium(.gray800)
                if let onConnect {
                    Button(action: onConnect) {
                        Text("연결하기")
                            .body_02_semibold(.greenDark)
                            .padding(.horizontal, Spacing.x4)
                            .padding(.vertical, 10)
                            .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var connectedContent: some View {
        dayBars("수면 시간", summary: record.sleepAverageText.map { "평균 \($0)" }, days: record.sleep) {
            LifeRecord.sleepText(Int($0))
        }
        dayBars("걸음", summary: record.stepsAverageText.map { "평균 \($0)" }, days: record.steps) {
            "\(Int($0))걸음"
        }
        .padding(.top, Spacing.x1)

        DividerLine()

        VStack(spacing: 0) {
            latestRow("안정 시 심박", record.restingHeartRate)
            latestRow("혈압", record.bloodPressure)
            latestRow("혈당", record.bloodGlucose)
        }

        VStack(alignment: .leading, spacing: Spacing.x1) {
            if let lastSynced = record.lastSyncedText {
                Text("마지막 동기화 \(lastSynced)")
                    .caption_01_regular(.gray700)
            }
            Text(record.disclaimer)
                .caption_02_regular(.gray700)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 7일 막대. 기록이 없는 날은 바닥에 옅은 자리만 둔다.
    private func dayBars(
        _ title: String,
        summary: String?,
        days: [LifeRecordDay],
        valueText: @escaping (Double) -> String
    ) -> some View {
        let maximum = max(days.compactMap(\.value).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: Spacing.x3) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .body_01_semibold(.gray900)
                Spacer(minLength: Spacing.x2)
                Text(summary ?? "기록이 없어요")
                    .body_03_medium(.gray800)
            }

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.value == nil ? Color.gray200 : Color.greenNormal)
                            .frame(width: 14, height: day.value.map { max(barAreaHeight * $0 / maximum, 4) } ?? 4)
                            .frame(height: barAreaHeight, alignment: .bottom)
                        Text(day.label)
                            .caption_02_regular(.gray700)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.label) \(day.value.map(valueText) ?? "기록 없음")")
                }
            }
        }
    }

    private func latestRow(_ label: String, _ latest: LifeRecordLatest?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
            Text(label)
                .body_02_medium(.gray800)
            Spacer(minLength: Spacing.x2)
            if let latest {
                Text(latest.value)
                    .body_01_semibold(.gray900)
                Text(latest.unit)
                    .caption_01_regular(.gray800)
                Text(latest.dateText)
                    .caption_01_regular(.gray700)
                    .padding(.leading, 6)
            } else {
                Text("기록 없음")
                    .body_03_medium(.gray700)
            }
        }
        .padding(.vertical, 7)
    }
}

#Preview {
    let today = HealthDailyCalculator.dayOf(Date())
    ScrollView {
        VStack(spacing: Spacing.x3) {
            LifeRecordCardView(record: .sample(end: today, today: today))
            LifeRecordCardView(
                record: LifeRecord(
                    dto: ParentHealthDailyDTO(
                        parentId: "me", connected: false, platform: nil, lastSyncedDay: nil, days: [], disclaimer: nil
                    ),
                    end: today,
                    today: today
                ),
                onConnect: {}
            )
        }
        .padding()
    }
    .background(Color.gray50)
}
