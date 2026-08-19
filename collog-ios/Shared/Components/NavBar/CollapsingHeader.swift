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
    private let scrollReset: Int
    private let sticky: AnyView?
    private let pinnedSticky: AnyView?
    private let showsScrollToTopButton: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var pullDistance: CGFloat = 0
    @State private var isRefreshArmed = false
    @State private var stickyMinY = CGFloat.greatestFiniteMagnitude
    @State private var scrollToTopRequest = 0

    private let collapseDistance: CGFloat = 44
    private let barHeight: CGFloat = 52
    private let refreshThreshold: CGFloat = 68
    private let refreshHoldHeight: CGFloat = 44

    init(
        title: String,
        onRefresh: (@MainActor @Sendable () async -> Void)? = nil,
        scrollReset: Int = 0,
        showsScrollToTopButton: Bool = false,
        @ViewBuilder large: () -> Large,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.large = large()
        self.trailing = trailing()
        self.content = content()
        self.onRefresh = onRefresh
        self.scrollReset = scrollReset
        self.showsScrollToTopButton = showsScrollToTopButton
        sticky = nil
        pinnedSticky = nil
    }

    init<Sticky: View, PinnedSticky: View>(
        title: String,
        onRefresh: (@MainActor @Sendable () async -> Void)? = nil,
        scrollReset: Int = 0,
        showsScrollToTopButton: Bool = false,
        @ViewBuilder large: () -> Large,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder sticky: () -> Sticky,
        @ViewBuilder pinnedSticky: () -> PinnedSticky,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.large = large()
        self.trailing = trailing()
        self.content = content()
        self.onRefresh = onRefresh
        self.scrollReset = scrollReset
        self.showsScrollToTopButton = showsScrollToTopButton
        self.sticky = AnyView(sticky())
        self.pinnedSticky = AnyView(pinnedSticky())
    }

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseDistance, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            contentScrollView

            if let pinnedSticky, isSticky {
                pinnedSticky
                    .background(Color.gray50)
                    .padding(.top, barHeight)
                    .transition(.opacity)
            }

            compactBar
        }
        .background(Color.gray50)
        .overlay(alignment: .bottomTrailing) {
            if shouldShowScrollToTopButton {
                scrollToTopButton
                    .padding(.trailing, Spacing.x5)
                    .padding(.bottom, Spacing.x5)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.22), value: shouldShowScrollToTopButton)
    }

    private var isSticky: Bool {
        sticky != nil && stickyMinY <= barHeight
    }

    private var shouldShowScrollToTopButton: Bool {
        showsScrollToTopButton && scrollOffset > 520 && !isRefreshing
    }

    private var scrollToTopButton: some View {
        Button {
            Haptics.press()
            scrollToTopRequest += 1
        } label: {
            Icon(name: "chevron.up", size: 20, weight: .semibold, color: .gray00)
                .frame(width: 48, height: 48)
                .background(Color.gray900.opacity(0.94), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("최상단으로 이동")
    }

    private var contentScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.gray700)
                            .frame(maxWidth: .infinity)
                            .frame(height: refreshHoldHeight)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    large
                        .padding(.horizontal, Spacing.x5)
                        .padding(.top, Spacing.x2)
                        .padding(.bottom, Spacing.x6)
                        .opacity(1 - collapseProgress)

                    if let sticky {
                        sticky
                            .background(Color.gray50)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.frame(in: .scrollView(axis: .vertical)).minY
                            } action: { minY in
                                stickyMinY = minY
                            }
                            .opacity(isSticky ? 0 : 1)
                            .allowsHitTesting(!isSticky)
                    }

                    content
                }
                .padding(.top, barHeight)
                .id(ScrollTarget.top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
                updatePullDistance(offset)
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                guard oldPhase == .interacting, newPhase != .interacting else { return }
                finishPull()
            }
            .onChange(of: scrollReset) {
                withAnimation(.smooth(duration: 0.32)) {
                    proxy.scrollTo(ScrollTarget.top, anchor: .top)
                }
            }
            .onChange(of: scrollToTopRequest) {
                withAnimation(.smooth(duration: 0.4)) {
                    proxy.scrollTo(ScrollTarget.top, anchor: .top)
                }
            }
        }
    }

    private enum ScrollTarget {
        case top
    }

    private func updatePullDistance(_ offset: CGFloat) {
        guard onRefresh != nil, !isRefreshing else { return }
        pullDistance = max(-offset, 0)

        guard pullDistance >= refreshThreshold, !isRefreshArmed else { return }
        isRefreshArmed = true
        Haptics.focus()
    }

    private func finishPull() {
        guard !isRefreshing else { return }
        pullDistance = 0

        guard isRefreshArmed, let onRefresh else {
            isRefreshArmed = false
            return
        }

        isRefreshArmed = false
        withAnimation(.smooth(duration: 0.24)) { isRefreshing = true }

        Task { @MainActor in
            let minimumDuration = Task {
                try? await Task.sleep(for: .milliseconds(650))
            }
            await onRefresh()
            await minimumDuration.value
            withAnimation(.smooth(duration: 0.28)) { isRefreshing = false }
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
        scrollReset: Int = 0,
        showsScrollToTopButton: Bool = false,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            onRefresh: onRefresh,
            scrollReset: scrollReset,
            showsScrollToTopButton: showsScrollToTopButton,
            large: { CollapsingLargeTitle(title: title) },
            trailing: trailing,
            content: content
        )
    }

    init<Sticky: View, PinnedSticky: View>(
        title: String,
        onRefresh: (@MainActor @Sendable () async -> Void)? = nil,
        scrollReset: Int = 0,
        showsScrollToTopButton: Bool = false,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder sticky: () -> Sticky,
        @ViewBuilder pinnedSticky: () -> PinnedSticky,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            onRefresh: onRefresh,
            scrollReset: scrollReset,
            showsScrollToTopButton: showsScrollToTopButton,
            large: { CollapsingLargeTitle(title: title) },
            trailing: trailing,
            sticky: sticky,
            pinnedSticky: pinnedSticky,
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
