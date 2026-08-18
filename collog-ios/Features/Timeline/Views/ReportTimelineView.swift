//
//  ReportTimelineView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ReportTimelineView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(NavigationStore.self) private var navigation
    @Environment(TabManager.self) private var tabManager

    @State private var viewModel: TimelineViewModel
    @State private var pagedOffset: Int? = 0
    @State private var pageHeights: [Int: CGFloat] = [:]

    private let tab: MainTab
    private let pageOffsets = Array(-25...0)

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
        tab = initialTabIndex == 0 ? .report : .timeline
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: tab)

        return NavigationStack(path: $navigator.path) {
            CollapsingHeaderScrollView(
                title: viewModel.title,
                onRefresh: refresh,
                scrollReset: tabManager.reselectionCount
            ) {
                FilterChipView(label: viewModel.selectedMember)
            } content: {
                VStack(spacing: 0) {
                    WeekNavigatorView(
                        title: viewModel.week.title,
                        rangeText: viewModel.week.rangeText,
                        canGoForward: viewModel.canGoForward,
                        onPrevious: { move(by: -1) },
                        onNext: { move(by: 1) }
                    )

                    weekPager
                }
                .padding(.bottom, Spacing.x8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.refresh(using: environment) }
            .onChange(of: tabManager.reselectionCount) {
                guard tabManager.reselectedTab == tab else { return }
                moveToCurrentWeek()
            }
        }
    }

    private var weekPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(pageOffsets, id: \.self) { offset in
                    pageView(for: offset)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .scrollPosition(id: $pagedOffset)
        .frame(height: currentPageHeight)
        .onScrollPhaseChange { _, phase in
            guard phase == .idle else { return }
            settlePage()
        }
    }

    private var currentPageHeight: CGFloat {
        max(pageHeights[viewModel.weekOffset] ?? 340, 240)
    }

    @ViewBuilder
    private func pageView(for offset: Int) -> some View {
        Group {
            if abs(offset - viewModel.weekOffset) <= 1 {
                let page = viewModel.page(for: offset)

                if page.isLoaded {
                    weekContent(page)
                } else {
                    loadingContent
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            guard height > 0 else { return }
            pageHeights[offset] = height
        }
    }

    private func settlePage() {
        guard let pagedOffset, pagedOffset != viewModel.weekOffset else { return }
        Haptics.focus()
        viewModel.setWeek(pagedOffset)
        Task { await viewModel.refresh(using: environment) }
    }

    private func refresh() async {
        await viewModel.refresh(using: environment, forceReload: true)
    }

    private func move(by delta: Int) {
        let target = viewModel.weekOffset + delta
        guard pageOffsets.contains(target) else { return }

        withAnimation(.smooth(duration: 0.32)) {
            pagedOffset = target
        }
    }

    private func moveToCurrentWeek() {
        guard pagedOffset != 0 else { return }
        withAnimation(.smooth(duration: 0.32)) {
            pagedOffset = 0
        }
    }

    @ViewBuilder
    private func weekContent(_ page: TimelineWeekPage) -> some View {
        if viewModel.selectedTabIndex == 1 {
            timelineEntries(page)
        } else {
            reportContent(page)
        }
    }

    @ViewBuilder
    private func reportContent(_ page: TimelineWeekPage) -> some View {
        if page.report.summaryStats.isEmpty {
            EmptyStateView(
                symbol: "doc.text.magnifyingglass",
                title: "이번 주 리포트가 아직 없어요",
                message: "분석된 통화가 쌓이면 변화를 정리해드려요."
            )
            .padding(.top, Spacing.x6)
        } else {
            ReportContentView(report: page.report, isLoaded: true)
                .padding(.horizontal, Spacing.x5)
                .padding(.top, Spacing.x2)
        }
    }

    @ViewBuilder
    private func timelineEntries(_ page: TimelineWeekPage) -> some View {
        if page.entries.isEmpty {
            EmptyStateView(
                symbol: "phone.badge.waveform",
                title: "이번 주에는 분석된 통화가 없어요",
                message: "가족과 통화하면 이곳에 기록이 쌓여요."
            )
            .padding(.top, Spacing.x6)
        } else {
            VStack(spacing: 0) {
                ForEach(page.entries) { entry in
                    CallTimelineDateHeader(entry: entry)

                    CallTimelineCardView(entry: entry)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.bottom, Spacing.x6)
                }
            }
        }
    }

    private var loadingContent: some View {
        VStack(spacing: Spacing.x4) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.gray100)
                    .frame(height: 148)
            }
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x4)
    }
}

#Preview {
    let environment = AppEnvironment()

    ReportTimelineView()
        .environment(environment)
        .environment(NavigationStore())
}
