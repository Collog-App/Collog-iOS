//
//  ReportTimelineView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ReportTimelineView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: TimelineViewModel

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header

                WeekNavigatorView(title: viewModel.week.title, rangeText: viewModel.week.rangeText)

                if viewModel.selectedTabIndex == 1 {
                    timelineSections
                } else {
                    ReportContentView(report: viewModel.report)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.top, Spacing.x2)
                }
            }
            .padding(.bottom, Spacing.x8)
        }
        .scrollIndicators(.hidden)
        .background(Color.gray50)
        .task { await viewModel.refresh(using: environment) }
    }

    @ViewBuilder
    private var timelineSections: some View {
        if viewModel.week.entries.isEmpty {
            Text("이번 주에는 분석된 통화가 없어요")
                .body_02_medium(.gray700)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.x5)
                .padding(.top, Spacing.x6)
        } else {
            ForEach(viewModel.week.entries) { entry in
                Section {
                    CallTimelineCardView(entry: entry)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.bottom, Spacing.x6)
                } header: {
                    CallTimelineDateHeader(entry: entry)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.x2) {
            Text(viewModel.title)
                .subtitle_01(.gray900)

            Spacer(minLength: Spacing.x2)

            FilterChipView(label: viewModel.selectedMember)
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x2)
        .padding(.bottom, Spacing.x4)
    }
}

#Preview {
    ReportTimelineView()
        .environment(AppEnvironment())
}
