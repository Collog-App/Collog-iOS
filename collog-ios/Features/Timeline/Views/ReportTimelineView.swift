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
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: TimelineViewModel
    @State private var pagedOffset: Int? = 0
    @State private var pageHeights: [Int: CGFloat] = [:]
    @State private var activeVerticalWeek = 0
    @State private var weekHeaderMinYs: [Int: CGFloat] = [:]
    @State private var memberSelectionCount = 0

    private let tab: MainTab
    private let pageOffsets = Array(-25...0)
    private let verticalPageOffsets = Array((-25...0).reversed())

    private var subjects: [FamilyContact] { viewModel.subjects(using: environment) }

    /// 가족 = 기존 그린, 나 = 주황. 게스트처럼 선택된 사람이 없으면 그린
    private var accent: ViewerAccent {
        viewModel.isSelfSelected ? .mine : .family
    }

    private var displayTitle: String {
        if viewModel.isSelfSelected { return "나의 \(viewModel.title)" }
        guard viewModel.selectedContactId != nil else { return viewModel.title }
        return "\(viewModel.selectedMember)님의 \(viewModel.title)"
    }

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
        tab = initialTabIndex == 0 ? .report : .timeline
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: tab)

        return NavigationStack(path: $navigator.path) {
            CollapsingHeaderScrollView(
                title: displayTitle,
                onRefresh: refresh,
                scrollReset: tabManager.reselectionCount + memberSelectionCount,
                showsScrollToTopButton: tab == .timeline,
                large: {
                    VStack(alignment: .leading, spacing: Spacing.x4) {
                        ViewerProfileHeader(
                            subjects: subjects,
                            selectedId: viewModel.selectedContactId,
                            onSelect: select
                        )
                        CollapsingLargeTitle(title: displayTitle)
                    }
                },
                trailing: {
                    ViewerBadgeChip(name: viewModel.selectedMember)
                },
                sticky: {
                if tab == .timeline {
                    timelineSectionHeader(for: activeVerticalWeek)
                }
                },
                pinnedSticky: {
                    if tab == .timeline {
                        stickyTimelineWeekHeader
                    }
                },
                content: {
                VStack(spacing: Spacing.x3) {
                    if tab == .timeline {
                        verticalTimeline
                            .simultaneousGesture(personSwipe)
                    } else {
                        VStack(spacing: 0) {
                            weekNavigator

                            weekPager
                        }
                    }
                }
                .padding(.bottom, Spacing.x8)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CallAnalysisRoute.self) { route in
                CallAnalysisView(callId: route.callId)
            }
            .task { await viewModel.refresh(using: environment) }
            // 내 건강 앱을 연결·동기화·끊으면 내 리포트의 「생활 기록」을 다시 불러온다
            .onChange(of: environment.health.revision) {
                guard tab == .report, viewModel.isSelfSelected else { return }
                Task { await viewModel.refresh(using: environment, forceReload: true) }
            }
            // 분석 완료 알림을 받으면(누르지 않고 배너로만 봐도) 이미 불러 둔 리포트를 다시 읽는다
            .onChange(of: environment.reportDataRevision) {
                Task { await viewModel.refresh(using: environment, forceReload: true) }
            }
            // 앱으로 돌아왔을 때: 그사이 가족이 공유를 껐으면 보이던 기록을 남겨 두지 않는다
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { await viewModel.revalidateSharing(using: environment) }
            }
            .onChange(of: tabManager.reselectionCount) {
                guard tabManager.reselectedTab == tab else { return }
                moveToCurrentWeek()
            }
        }
        .environment(\.viewerAccent, accent)
        .onAppear { environment.viewerAccent = accent }
        .onChange(of: accent) { environment.viewerAccent = accent }
        .onDisappear { environment.viewerAccent = .family }
    }

    private var weekNavigator: some View {
        WeekNavigatorView(
            title: viewModel.week.title,
            rangeText: viewModel.week.rangeText,
            canGoForward: viewModel.canGoForward,
            onPrevious: { move(by: -1) },
            onNext: { move(by: 1) }
        )
        .background(accent.background)
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

    /// 타임라인 본문에서 옆으로 밀면 이전·다음 사람으로 바뀐다. 리포트는 주차 가로 페이저가 있어 헤더에서만 바꾼다.
    private var personSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 70, abs(dx) > abs(value.translation.height) * 2 else { return }
                selectNeighbor(dx < 0 ? 1 : -1)
            }
    }

    private func selectNeighbor(_ delta: Int) {
        let list = subjects
        guard let id = viewModel.selectedContactId,
              let index = list.firstIndex(where: { $0.id == id }),
              list.indices.contains(index + delta) else { return }
        select(list[index + delta])
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
            memberSelectionCount += 1
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

    private func reportContent(_ page: TimelineWeekPage) -> some View {
        VStack(spacing: Spacing.x3) {
            // 응급 안내(11-08 가드레일)는 리포트 맨 위. 누르면 그 통화의 분석 화면을 연다
            if page.reportError == nil, !page.report.safetyNotices.isEmpty {
                safetyNotices(page.report.safetyNotices)
            }

            if page.reportNotShared {
                NotSharedStateView()
            } else if let error = page.reportError {
                errorContent(error, offset: page.offset)
            } else if page.report.state == .empty {
                if let error = page.timelineError {
                    errorContent(error, offset: page.offset)
                } else {
                    emptyAnalysisContent(page)
                }
            } else {
                ReportContentView(report: page.report, isLoaded: true)
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x2)
            }

            // 생활 기록(건강 앱 연결). 내 리포트에서만 「연결하기」를 보인다
            if let record = page.lifeRecord {
                LifeRecordCardView(
                    record: record,
                    onConnect: viewModel.isSelfSelected ? { environment.health.present() } : nil
                )
                .padding(.horizontal, Spacing.x5)
            }
        }
    }

    private func safetyNotices(_ notices: [SafetyNotice]) -> some View {
        VStack(spacing: Spacing.x2) {
            ForEach(notices) { notice in
                if notice.callId.isEmpty {
                    SafetyNoticeCardView(text: notice.text, caption: notice.dayText)
                } else {
                    Button {
                        navigation.manager(for: tab).push(CallAnalysisRoute(callId: notice.callId))
                    } label: {
                        SafetyNoticeCardView(text: notice.text, caption: notice.dayText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x2)
    }

    @ViewBuilder
    private func timelineEntries(_ page: TimelineWeekPage) -> some View {
        if page.timelineNotShared {
            NotSharedStateView()
        } else if let error = page.timelineError {
            errorContent(error, offset: page.offset)
        } else if page.entries.isEmpty {
            emptyAnalysisContent(page)
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

    private func emptyAnalysisContent(_ page: TimelineWeekPage) -> some View {
        AnalysisEmptyStateView(
            contact: environment.family.contacts.first { $0.id == viewModel.selectedContactId },
            isSelf: viewModel.isSelfSelected,
            calls: page.calls,
            isCurrentWeek: page.offset == 0,
            onCurrentWeek: moveToCurrentWeek,
            onRefresh: {
                await environment.family.refresh(using: environment)
                await viewModel.loadPage(page.offset, using: environment, forceReload: true)
            }
        )
    }

    private func errorContent(_ message: String, offset: Int) -> some View {
        EmptyStateView(
            symbol: "exclamationmark.circle",
            title: "데이터를 불러오지 못했어요.",
            message: message,
            actionTitle: "다시 시도"
        ) {
            Task { await viewModel.loadPage(offset, using: environment, forceReload: true) }
        }
    }

    private func timelineEvent(_ entry: CallTimelineEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.x3) {
            CallTimelineRail(isLast: isLast)

            VStack(alignment: .leading, spacing: Spacing.x3) {
                CallTimelineDateHeader(entry: entry)
                if let safetyNotice = entry.safetyNotice {
                    SafetyNoticeCardView(text: safetyNotice)
                }
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
        .environment(CallCenter(environment: environment))
        .environment(NavigationStore())
}
