//
//  FamilySharingModel.swift
//  collog-ios
//

import SwiftUI

/// 「가족별 공유 설정」 상태: 내 리포트·타임라인을 가족 구성원마다 보일지 정한다.
/// 둘러보기에서는 서버를 부르지 않는다.
@Observable
final class FamilySharingModel {
    private(set) var shares: [FamilyShare] = []
    private(set) var hasLoaded = false
    private(set) var isSubmitting = false
    private(set) var errorText: String?

    func load(using environment: AppEnvironment) async {
        guard !environment.settings.isGuestMode, environment.session.isAuthenticated else { return }
        errorText = nil
        do {
            shares = try await environment.api.sharing()
            hasLoaded = true
        } catch is CancellationError {
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// 스위치를 바꾸면 화면에 먼저 반영하고 저장한다. 저장하지 못하면 되돌리고 이유를 보인다.
    func update(
        _ viewerUserId: String,
        report: Bool? = nil,
        timeline: Bool? = nil,
        using environment: AppEnvironment
    ) async {
        guard !isSubmitting, !environment.settings.isGuestMode else { return }
        let previous = shares
        let next = shares.updating(viewerUserId, report: report, timeline: timeline)
        guard next != previous else { return }
        shares = next
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            shares = try await environment.api.updateSharing(next.filter { $0.viewerUserId == viewerUserId })
        } catch {
            shares = previous
            errorText = error.localizedDescription
        }
    }
}

extension [FamilyShare] {
    /// `viewerUserId`의 한 줄만 바꾼 새 목록.
    func updating(_ viewerUserId: String, report: Bool? = nil, timeline: Bool? = nil) -> [FamilyShare] {
        map { share in
            guard share.viewerUserId == viewerUserId else { return share }
            var updated = share
            updated.report = report ?? share.report
            updated.timeline = timeline ?? share.timeline
            return updated
        }
    }
}
