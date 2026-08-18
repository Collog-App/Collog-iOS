//
//  CollapsingHeader.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct CollapsingHeaderScrollView<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    @State private var scrollOffset: CGFloat = 0

    private let collapseDistance: CGFloat = 44
    private let barHeight: CGFloat = 52

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseDistance, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .headline_02(.gray900)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.top, Spacing.x2)
                        .padding(.bottom, Spacing.x4)
                        .opacity(1 - collapseProgress)

                    content
                }
                .padding(.top, barHeight)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }

            compactBar
        }
        .background(Color.gray50)
    }

    private var compactBar: some View {
        HStack(spacing: Spacing.x2) {
            Text(title)
                .body_01_semibold(.gray900)
                .opacity(collapseProgress)

            Spacer(minLength: Spacing.x2)

            trailing
        }
        .padding(.horizontal, Spacing.x5)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background {
            Color.gray50
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.gray200)
                        .frame(height: 1)
                        .opacity(collapseProgress)
                }
        }
    }
}

#Preview {
    CollapsingHeaderScrollView(title: "리포트") {
        FilterChipView(label: "어머니")
    } content: {
        VStack(spacing: 12) {
            ForEach(0..<12, id: \.self) { index in
                Text("행 \(index)")
                    .body_02_medium(.gray900)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            }
        }
        .padding(.horizontal, Spacing.x5)
    }
}
