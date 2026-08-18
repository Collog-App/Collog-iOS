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

    @State private var viewModel: TimelineViewModel
    @State private var pagedOffset: Int?

    private let tab: MainTab
    private let pageOffsets = Array((-25...0).reversed())

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
        tab = initialTabIndex == 0 ? .report : .timeline
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: tab)

        return NavigationStack(path: $navigator.path) {
            CollapsingHeaderScrollView(title: viewModel.title) {
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
            .task {
                pagedOffset = viewModel.weekOffset
                await viewModel.refresh(using: environment)
            }
        }
    }

    private var weekPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pageOffsets, id: \.self) { offset in
                    page(for: offset)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $pagedOffset)
        .onChange(of: pagedOffset) { _, newValue in
            guard let newValue, newValue != viewModel.weekOffset else { return }
            Haptics.press()
            viewModel.setWeek(newValue)
            Task { await viewModel.refresh(using: environment) }
        }
    }

    @ViewBuilder
    private func page(for offset: Int) -> some View {
        Group {
            if offset == viewModel.weekOffset {
                weekContent
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .top)
    }

    private func move(by delta: Int) {
        let target = viewModel.weekOffset + delta
        guard pageOffsets.contains(target) else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            pagedOffset = target
        }
    }

    @ViewBuilder
    private var weekContent: some View {
        if viewModel.selectedTabIndex == 1 {
            timelineEntries
        } else {
            reportContent
        }
    }

    @ViewBuilder
    private var reportContent: some View {
        if viewModel.isLiveData, viewModel.report.summaryStats.isEmpty {
            EmptyStateView(
                symbol: "doc.text.magnifyingglass",
                title: "이번 주 리포트가 아직 없어요",
                message: "분석된 통화가 쌓이면 변화를 정리해드려요."
            )
            .padding(.top, Spacing.x6)
        } else {
            ReportContentView(report: viewModel.report, isLoaded: viewModel.isLiveData)
                .padding(.horizontal, Spacing.x5)
                .padding(.top, Spacing.x2)
        }
    }

    @ViewBuilder
    private var timelineEntries: some View {
        if viewModel.week.entries.isEmpty {
            EmptyStateView(
                symbol: "phone.badge.waveform",
                title: "이번 주에는 분석된 통화가 없어요",
                message: "가족과 통화하면 이곳에 기록이 쌓여요."
            )
            .padding(.top, Spacing.x6)
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.week.entries) { entry in
                    CallTimelineDateHeader(entry: entry)

                    CallTimelineCardView(entry: entry)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.bottom, Spacing.x6)
                }
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment()

    ReportTimelineView()
        .environment(environment)
        .environment(NavigationStore())
}
