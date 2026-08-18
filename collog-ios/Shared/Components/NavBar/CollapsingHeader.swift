//
//  CollapsingHeader.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct CollapsingLargeTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .headline_02(.gray900)
    }
}

struct CollapsingHeaderScrollView<Large: View, Trailing: View, Content: View>: View {
    private let title: String
    private let large: Large
    private let trailing: Trailing
    private let content: Content
    private let onRefresh: (@MainActor @Sendable () async -> Void)?

    @State private var scrollOffset: CGFloat = 0

    private let collapseDistance: CGFloat = 44
    private let barHeight: CGFloat = 52

    init(
        title: String,
        onRefresh: (@MainActor @Sendable () async -> Void)? = nil,
        @ViewBuilder large: () -> Large,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.large = large()
        self.trailing = trailing()
        self.content = content()
        self.onRefresh = onRefresh
    }

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseDistance, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            refreshableScrollView

            compactBar
        }
        .background(Color.gray50)
    }

    @ViewBuilder
    private var refreshableScrollView: some View {
        if let onRefresh {
            contentScrollView
                .refreshable {
                    await onRefresh()
                }
        } else {
            contentScrollView
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                large
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x2)
                    .padding(.bottom, Spacing.x6)
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
        }
    }
}

extension CollapsingHeaderScrollView where Large == CollapsingLargeTitle {
    init(
        title: String,
        onRefresh: (@MainActor @Sendable () async -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            onRefresh: onRefresh,
            large: { CollapsingLargeTitle(title: title) },
            trailing: trailing,
            content: content
        )
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
