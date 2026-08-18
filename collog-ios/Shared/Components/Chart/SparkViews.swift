//
//  SparkViews.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct SparkBarView: View {
    let values: [Double]
    var highlightCount: Int = 3
    var barWidth: CGFloat = 10
    var spacing: CGFloat = 4

    @State private var revealed = false

    private var maximum: Double { max(values.max() ?? 1, 0.0001) }

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isHighlighted(index) ? Color.greenNormal : Color.gray300)
                    .frame(width: barWidth)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .scaleEffect(y: revealed ? heightRatio(value) : 0, anchor: .bottom)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.04),
                        value: revealed
                    )
            }
        }
        .onAppear { revealed = true }
    }

    private func heightRatio(_ value: Double) -> CGFloat {
        max(CGFloat(value / maximum), 0.08)
    }

    private func isHighlighted(_ index: Int) -> Bool {
        index >= values.count - highlightCount
    }
}

struct SparkLineView: View {
    let values: [Double]
    var lineWidth: CGFloat = 2

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let points = points(in: proxy.size)

            ZStack(alignment: .topLeading) {
                path(through: points)
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.greenNormal,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                if let last = points.last {
                    Circle()
                        .fill(Color.greenNormal)
                        .frame(width: 7, height: 7)
                        .position(x: last.x, y: last.y)
                        .opacity(progress == 1 ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { progress = 1 }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let span = max(maximum - minimum, 0.0001)
        let step = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let ratio = (value - minimum) / span
            return CGPoint(
                x: CGFloat(index) * step,
                y: size.height - CGFloat(ratio) * size.height
            )
        }
    }

    private func path(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        SparkBarView(values: [3, 4, 2, 5, 6, 8, 9])
            .frame(height: 44)

        SparkLineView(values: [229, 205, 212, 209, 216, 208])
            .frame(height: 44)
    }
    .padding()
    .background(Color.gray00)
}
