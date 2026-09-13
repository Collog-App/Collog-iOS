import Testing
@testable import collog_ios

@MainActor
struct ReportMappingTests {
    @Test(arguments: ["EMPTY", "READY", "BASELINE_COLLECTING"])
    func noAnalyzedCallsHideReportContent(state: String) {
        let report = WeeklyReport(dto: makeReport(count: 0, state: state), trend: .speechRateSample)

        #expect(report.state == .empty)
        #expect(report.summaryStats.isEmpty)
        #expect(report.conversationGroups.isEmpty)
        #expect(report.metricTrends.isEmpty)
        #expect(report.acousticTrend == nil)
    }

    @Test
    func analyzedCallsPreserveZeroMeasurements() {
        let report = WeeklyReport(dto: makeReport(count: 1, state: "READY"), trend: nil)

        #expect(report.state == .ready)
        #expect(report.summaryStats.first?.value == "1")
        #expect(report.repeatObservation.countText == "0")
        #expect(report.metricTrends.first?.values == [0, 0])
        #expect(report.metricTrends.first?.value == "0")
    }

    @Test
    func analyzedCallsKeepBaselineCollectionState() {
        let report = WeeklyReport(dto: makeReport(count: 1, state: "BASELINE_COLLECTING"), trend: nil)

        #expect(report.state == .baselineCollecting)
        #expect(!report.summaryStats.isEmpty)
    }

    private func makeReport(count: Int, state: String) -> ReportDTO {
        ReportDTO(
            parentId: "parent", period: "WEEK", from: "2026-09-07", to: "2026-09-13",
            state: state, emptyMessage: nil, disclaimer: "", advisory: nil,
            promotedSignals: [], acuteSignals: [], conversationItems: ["activity": ["산책"]],
            repeatObservation: RepeatObservationDTO(count: 0, callsWithRepeat: 0, label: ""),
            acousticTrends: [AcousticTrendDTO(metric: "COUGH_EVENTS", points: [
                AcousticTrendPointDTO(date: "2026-09-12", value: 0, unit: "회"),
                AcousticTrendPointDTO(date: "2026-09-13", value: 0, unit: "회")
            ])],
            recentAcousticHistory: nil, analyzedCallCount: count,
            containsDemoData: false, demoDataNotice: nil
        )
    }
}
