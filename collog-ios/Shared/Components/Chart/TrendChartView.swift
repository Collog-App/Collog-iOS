//
//  TrendChartView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Charts
import SwiftUI

struct TrendChartView: View {
    let series: TrendSeries

    @State private var selectedDate: Date?
    @State private var revealProgress: CGFloat = 0

    private var focusedPoint: TrendPoint? {
        guard let selectedDate else { return series.latest }
        return series.nearest(to: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            readout

            chart
                .frame(height: 132)
                .mask(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * revealProgress)
                    }
                }
                .onAppear {
                    guard revealProgress == 0 else { return }
                    withAnimation(.easeOut(duration: 0.9)) { revealProgress = 1 }
                }
        }
    }

    private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
            Text(focusedPoint?.label ?? series.metricName)
                .caption_01_medium(.gray800)

            Spacer(minLength: Spacing.x2)

            if let focusedPoint {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(Self.valueFormatter.string(from: focusedPoint.value as NSNumber) ?? "-")
                        .pretendard(.semiBold, 20, .gray900)
                    Text(series.unit)
                        .caption_01_medium(.gray800)
                }

                Text(series.isWithinNormalRange(focusedPoint) ? "평소 범위" : "평소와 다름")
                    .caption_01_medium(series.isWithinNormalRange(focusedPoint) ? .greenDark : .orange600)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(series.points) { point in
                AreaMark(
                    x: .value("주", point.date),
                    yStart: .value("평소 하한", series.normalRange.lowerBound),
                    yEnd: .value("평소 상한", series.normalRange.upperBound)
                )
                .foregroundStyle(Color.gray200)
                .accessibilityHidden(true)
            }

            RuleMark(y: .value("평소", series.median))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.gray400)
                .accessibilityHidden(true)

            ForEach(series.points) { point in
                LineMark(x: .value("주", point.date), y: .value(series.unit, point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.greenNormal)
                    .accessibilityLabel(point.label)
                    .accessibilityValue("\(Int(point.value)) \(series.unit)")
            }

            if let focusedPoint {
                PointMark(x: .value("주", focusedPoint.date), y: .value(series.unit, focusedPoint.value))
                    .symbolSize(120)
                    .foregroundStyle(Color.greenDark)
                    .accessibilityHidden(true)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: yDomain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel(anchor: value.index == 0 ? .topLeading : .topTrailing) {
                    if let date = value.as(Date.self), let point = series.nearest(to: date) {
                        Text(point.label)
                            .caption_01_medium(.gray700)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.padding(.vertical, Spacing.x2)
        }
    }

    private var axisDates: [Date] {
        guard let first = series.points.first, let last = series.points.last else { return [] }
        return first.date == last.date ? [first.date] : [first.date, last.date]
    }

    private var yDomain: ClosedRange<Double> {
        let values = series.points.map(\.value) + [series.normalRange.lowerBound, series.normalRange.upperBound]
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        let padding = max((maximum - minimum) * 0.25, 1)
        return (minimum - padding)...(maximum + padding)
    }

    private static let valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    TrendChartView(series: .speechRateSample)
        .padding()
        .background(Color.gray00)
}
