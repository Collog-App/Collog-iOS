//
//  ReportTimelineView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ReportTimelineView: View {
    @State private var viewModel: TimelineViewModel

    init(initialTabIndex: Int = 1) {
        _viewModel = State(initialValue: TimelineViewModel(selectedTabIndex: initialTabIndex))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            WeekNavigatorView(title: viewModel.week.title, rangeText: viewModel.week.rangeText)

            ScrollView {
                if viewModel.selectedTabIndex == 1 {
                    VStack(alignment: .leading, spacing: Spacing.x6) {
                        ForEach(viewModel.week.entries) { entry in
                            CallTimelineCardView(entry: entry)
                        }
                    }
                    .padding(.horizontal, Spacing.x5)
                    .padding(.bottom, Spacing.x8)
                } else {
                    ReportContentView(report: viewModel.report)
                        .padding(.horizontal, Spacing.x5)
                        .padding(.bottom, Spacing.x8)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.gray50)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: Spacing.x2) {
            UnderlineTabsView(
                titles: viewModel.tabTitles,
                selection: $viewModel.selectedTabIndex,
                size: 20
            )

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
}
