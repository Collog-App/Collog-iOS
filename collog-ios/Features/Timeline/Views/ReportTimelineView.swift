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
    @State private var dragTranslation: CGFloat = 0
    @State private var pushFromLeading = true

    private let tab: MainTab

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
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        content
                            .id(viewModel.weekOffset)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: pushFromLeading ? .leading : .trailing),
                                    removal: .move(edge: pushFromLeading ? .trailing : .leading)
                                )
                            )
                            .offset(x: dragTranslation)
                            .highPriorityGesture(weekSwipe)
                    } header: {
                        WeekNavigatorView(
                            title: viewModel.week.title,
                            rangeText: viewModel.week.rangeText,
                            canGoForward: viewModel.canGoForward,
                            onPrevious: { changeWeek(by: -1) },
                            onNext: { changeWeek(by: 1) }
                        )
                        .background(Color.gray50)
                    }
                }
                .padding(.bottom, Spacing.x8)
                .clipped()
            }
            .toolbar(.hidden, for: .navigationBar)
            .simultaneousGesture(weekSwipe)
            .task { await viewModel.refresh(using: environment) }
        }
    }

    private var weekSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                let resists = value.translation.width < 0 && !viewModel.canGoForward
                dragTranslation = value.translation.width * (resists ? 0.18 : 0.55)
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.4
                let passed = abs(value.translation.width) > 80

                guard horizontal, passed else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragTranslation = 0
                    }
                    return
                }
                changeWeek(by: value.translation.width > 0 ? -1 : 1)
            }
    }

    private func changeWeek(by delta: Int) {
        pushFromLeading = delta < 0
        dragTranslation = 0

        withAnimation(.easeOut(duration: 0.22)) {
            guard viewModel.moveWeek(delta) else { return }
        }
        Haptics.press()
        Task { await viewModel.refresh(using: environment) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.selectedTabIndex == 1 {
            timelineEntries
        } else {
            if viewModel.isLiveData, viewModel.report.summaryStats.first?.value == "0" {
                EmptyStateView(
                    symbol: "doc.text.magnifyingglass",
                    title: "이번 주 리포트가 아직 없어요",
                    message: "분석된 통화가 쌓이면 변화를 정리해드려요."
                )
                .padding(.top, Spacing.x8)
            } else {
                ReportContentView(report: viewModel.report, isLoaded: viewModel.isLiveData)
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x2)
            }
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
            .padding(.top, Spacing.x8)
        } else {
            ForEach(viewModel.week.entries) { entry in
                VStack(spacing: 0) {
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
