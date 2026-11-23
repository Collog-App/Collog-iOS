//
//  FamilyInvitationAccess.swift
//  collog-ios
//

import Foundation

enum FamilyInvitationAccess {
    /// 누구나 초대할 수 있다. 가족이 없으면 첫 초대 때 만든다.
    static func canInvite(isGuest: Bool, hasFamily: Bool, serverAllowsInvitations: Bool) -> Bool {
        !isGuest && (!hasFamily || serverAllowsInvitations)
    }

    /// 서버는 다른 사람이 있는 가족에 이미 속해 있으면 초대 수락을 거절(409)하므로, 혼자일 때만 코드 입력을 보인다.
    static func canEnterCode(isGuest: Bool, memberUserIds: [String?], userId: String?) -> Bool {
        !isGuest && !memberUserIds.contains { $0 != nil && $0 != userId }
    }
}
