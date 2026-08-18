//
//  RangeGaugeView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct RangeGauge: Identifiable {
    let id = UUID()
    let label: String
    let normalRange: ClosedRange<Double>
    let marker: Double
    let caption: String
}

struct RangeGaugeView: View {
    let gauge: RangeGauge

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text(gauge.label)
                .caption_01_medium(.gray800)

            VStack(alignment: .leading, spacing: Spacing.x2) {
                GeometryReader { proxy in
                    let width = proxy.size.width

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray200)
                            .frame(height: 5)

                        Capsule()
                            .fill(Color.greenNormal.opacity(0.5))
                            .frame(width: max(0, width * rangeWidth), height: 5)
                            .offset(x: width * clamped(gauge.normalRange.lowerBound))

                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.greenDark)
                            .frame(width: 3, height: 13)
                            .offset(x: width * clamped(gauge.marker) - 1.5)
                    }
                    .frame(height: 13)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 13)

                Text(gauge.caption)
                    .caption_01_medium(.gray700)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangeWidth: Double {
        clamped(gauge.normalRange.upperBound) - clamped(gauge.normalRange.lowerBound)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct RangeGaugeRowView: View {
    let gauges: [RangeGauge]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(gauges.enumerated()), id: \.element.id) { index, gauge in
                if index > 0 {
                    DividerLine(axis: .vertical)
                        .padding(.horizontal, Spacing.x4)
                }

                RangeGaugeView(gauge: gauge)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    RangeGaugeRowView(gauges: CallTimelineEntry.sample.gauges)
        .padding()
        .background(Color.gray00)
}
