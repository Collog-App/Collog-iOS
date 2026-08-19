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
    @State private var activeVerticalWeek = 0
    @State private var weekHeaderMinYs: [Int: CGFloat] = [:]
    @State private var memberSelectionCount = 0

    private let tab: MainTab
    private let pageOffsets = Array(-25...0)
    private let verticalPageOffsets = Array((-25...0).reversed())

    private var contacts: [FamilyContact] { environment.family.contacts }

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
                scrollReset: tabManager.reselectionCount + memberSelectionCount,
                showsScrollToTopButton: tab == .timeline
            ) {
                memberSelector
            } sticky: {
                if tab == .timeline {
                    timelineSectionHeader(for: activeVerticalWeek)
                }
            } pinnedSticky: {
                if tab == .timeline {
                    stickyTimelineWeekHeader
                }
            } content: {
                Group {
                    if tab == .timeline {
                        verticalTimeline
                    } else {
                        VStack(spacing: 0) {
                            weekNavigator

                            weekPager
                        }
                    }
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

    @ViewBuilder
    private var memberSelector: some View {
        if contacts.count > 1 {
            Menu {
                ForEach(contacts) { contact in
                    Button {
                        select(contact)
                    } label: {
                        if contact.id == viewModel.selectedContactId {
                            Label(contact.name, systemImage: "checkmark")
                        } else {
                            Text(contact.name)
                        }
                    }
                }
            } label: {
                FilterChipLabelView(label: viewModel.selectedMember)
            }
        } else {
            FilterChipLabelView(label: viewModel.selectedMember)
        }
    }

    private var weekNavigator: some View {
        WeekNavigatorView(
            title: viewModel.week.title,
            rangeText: viewModel.week.rangeText,
            canGoForward: viewModel.canGoForward,
            onPrevious: { move(by: -1) },
            onNext: { move(by: 1) }
        )
        .background(Color.gray50)
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

    private var verticalTimeline: some View {
        LazyVStack(spacing: 0) {
            ForEach(verticalPageOffsets, id: \.self) { offset in
                verticalWeek(offset)
            }
        }
    }

    private func verticalWeek(_ offset: Int) -> some View {
        let page = viewModel.page(for: offset)

        return VStack(spacing: 0) {
            if offset != 0 {
                timelineSectionHeader(for: offset)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .scrollView(axis: .vertical)).minY
                    } action: { minY in
                        updateActiveVerticalWeek(offset, minY: minY)
                    }
            }

            if page.isLoaded {
                timelineEntries(page)
            } else {
                loadingContent
                    .padding(.bottom, Spacing.x5)
            }
        }
        .padding(.bottom, Spacing.x8)
        .task {
            await viewModel.loadPage(offset, using: environment)
        }
    }

    private var stickyTimelineWeekHeader: some View {
        let page = viewModel.page(for: activeVerticalWeek)
        return TimelineWeekHeader(title: page.title, rangeText: page.timelineRangeText)
    }

    private func timelineSectionHeader(for offset: Int) -> some View {
        let page = viewModel.page(for: offset)
        return TimelineWeekHeader(title: page.title, rangeText: nil)
    }

    private func updateActiveVerticalWeek(_ offset: Int, minY: CGFloat) {
        weekHeaderMinYs[offset] = minY
        let threshold: CGFloat = 116
        let active = weekHeaderMinYs
            .filter { $0.value <= threshold }
            .max { $0.value < $1.value }?
            .key ?? 0

        guard active != activeVerticalWeek else { return }
        activeVerticalWeek = active
        viewModel.setWeek(active)
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

    private func select(_ contact: FamilyContact) {
        guard contact.id != viewModel.selectedContactId else { return }
        Haptics.focus()
        viewModel.selectMember(contact)
        pagedOffset = 0
        pageHeights.removeAll()
        activeVerticalWeek = 0
        weekHeaderMinYs.removeAll()
        memberSelectionCount += 1
        Task { await viewModel.refresh(using: environment) }
    }

    private func move(by delta: Int) {
        let target = viewModel.weekOffset + delta
        guard pageOffsets.contains(target) else { return }

        withAnimation(.smooth(duration: 0.32)) {
            pagedOffset = target
        }
    }

    private func moveToCurrentWeek() {
        if tab == .timeline {
            activeVerticalWeek = 0
            weekHeaderMinYs.removeAll()
            viewModel.setWeek(0)
            return
        }

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
            Text("분석된 통화가 없어요")
                .body_03_medium(.gray700)
                .padding(.horizontal, Spacing.x5)
                .padding(.vertical, Spacing.x6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(page.entries.enumerated()), id: \.element.id) { index, entry in
                    timelineEvent(
                        entry,
                        isLast: index == page.entries.count - 1
                    )
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.68)
                            .scaleEffect(phase.isIdentity ? 1 : 0.975)
                    }
                }
            }
        }
    }

    private func timelineEvent(_ entry: CallTimelineEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.x3) {
            CallTimelineRail(isLast: isLast)

            VStack(alignment: .leading, spacing: Spacing.x3) {
                CallTimelineDateHeader(entry: entry)
                CallTimelineCardView(entry: entry)

                if !isLast {
                    Color.clear
                        .frame(height: Spacing.x3)
                }
            }
        }
        .padding(.horizontal, Spacing.x5)
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
