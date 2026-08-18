//
//  KeywordTimelineView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

enum KeywordTone {
    case neutral
    case positive
    case caution
    case concern

    var tickColor: Color {
        switch self {
        case .neutral: .gray500
        case .positive: .greenNormal
        case .caution: .orange600
        case .concern: .red400
        }
    }

    var chipForeground: Color {
        self == .concern ? .red400 : .gray800
    }

    var chipBackground: Color {
        self == .concern ? .red100 : .gray100
    }
}

struct KeywordMark: Identifiable {
    let id = UUID()
    let position: Double
    let tone: KeywordTone
    let label: String?
}

struct KeywordTimelineView: View {
    let marks: [KeywordMark]

    private var topLabels: [KeywordMark] { marks.filter { $0.label != nil && $0.tone != .concern } }
    private var bottomLabels: [KeywordMark] { marks.filter { $0.label != nil && $0.tone == .concern } }

    var body: some View {
        VStack(spacing: Spacing.x1) {
            if !topLabels.isEmpty {
                chipRow(for: topLabels, pointerBelow: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.gray100)

                    ForEach(marks) { mark in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(mark.tone.tickColor)
                            .frame(width: 3)
                            .offset(x: xPosition(for: mark, in: proxy.size.width))
                    }
                }
            }
            .frame(height: 14)

            if !bottomLabels.isEmpty {
                chipRow(for: bottomLabels, pointerBelow: false)
            }
        }
    }

    private func chipRow(for items: [KeywordMark], pointerBelow: Bool) -> some View {
        GeometryReader { proxy in
            ForEach(items) { mark in
                VStack(spacing: 0) {
                    if pointerBelow { chip(for: mark) }
                    Triangle()
                        .fill(mark.tone.chipBackground)
                        .frame(width: 9, height: 4)
                        .rotationEffect(.degrees(pointerBelow ? 0 : 180))
                    if !pointerBelow { chip(for: mark) }
                }
                .position(
                    x: chipCenter(for: mark, in: proxy.size.width),
                    y: proxy.size.height / 2
                )
            }
        }
        .frame(height: 26)
    }

    private func chip(for mark: KeywordMark) -> some View {
        Text(mark.label ?? "")
            .caption_02_semibold(mark.tone.chipForeground)
            .padding(.horizontal, Spacing.x3)
            .padding(.vertical, Spacing.x1)
            .background(mark.tone.chipBackground, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    private func xPosition(for mark: KeywordMark, in width: CGFloat) -> CGFloat {
        min(max(width * mark.position, 0), max(width - 3, 0))
    }

    private func chipCenter(for mark: KeywordMark, in width: CGFloat) -> CGFloat {
        let estimatedHalfWidth = CGFloat((mark.label?.count ?? 0) * 6 + 24) / 2
        return min(max(width * mark.position, estimatedHalfWidth), max(width - estimatedHalfWidth, estimatedHalfWidth))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    KeywordTimelineView(marks: CallTimelineEntry.sample.keywords)
        .padding()
        .background(Color.gray00)
}
