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

    private let tab: MainTab

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
        tab = initialTabIndex == 0 ? .report : .timeline
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: tab)

        return NavigationStack(path: $navigator.path) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        content
                    } header: {
                        WeekNavigatorView(
                            title: viewModel.week.title,
                            rangeText: viewModel.week.rangeText
                        )
                        .background(Color.gray50)
                    }
                }
                .padding(.bottom, Spacing.x8)
            }
            .scrollIndicators(.hidden)
            .background(Color.gray50)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    FilterChipView(label: viewModel.selectedMember)
                }
            }
            .toolbarBackground(Color.gray50, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await viewModel.refresh(using: environment) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.selectedTabIndex == 1 {
            timelineEntries
        } else {
            ReportContentView(report: viewModel.report)
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
