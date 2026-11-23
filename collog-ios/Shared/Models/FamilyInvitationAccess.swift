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

/// 홈의 가족 연결 안내. 아직 아무와도 연결되지 않은 사람에게만 띄운다.
enum FamilyConnectGuide: Equatable {
    /// 구성원도 보낸 초대도 없다: 초대하는 법을 순서대로 알려 준다.
    case invite
    /// 보낸 초대 가운데 아직 쓸 수 있는 것이 있고 수락을 기다린다.
    case waiting
    /// 보낸 초대가 모두 만료됐다: 구성원 관리에서 새 코드를 만들어야 한다.
    case expired

    /// 「초대 코드 입력」과 같은 조건에서만 띄운다. 구성원 목록을 아직 읽지 못했으면(nil) 띄우지 않는다.
    /// `hasUnexpiredInvitation`: 수락되지 않은 초대 가운데 만료되지 않은 것이 하나라도 있는지.
    static func resolve(
        isGuest: Bool, memberUserIds: [String?]?, userId: String?, hasUnexpiredInvitation: Bool
    ) -> Self? {
        guard let memberUserIds,
              FamilyInvitationAccess.canEnterCode(isGuest: isGuest, memberUserIds: memberUserIds, userId: userId)
        else { return nil }
        guard memberUserIds.contains(where: { $0 == nil }) else { return .invite }
        return hasUnexpiredInvitation ? .waiting : .expired
    }

    /// 수락되지 않은 내 초대가 있다(만료 포함). 받은 초대 코드를 넣으면 서버가 혼자뿐인 내 가족을 정리해 이 초대도 사라진다.
    var hasSentInvitation: Bool { self != .invite }

    var title: String {
        switch self {
        case .invite: "가족과 연결해 보세요"
        case .waiting: "초대 수락을 기다리고 있어요"
        case .expired: "보낸 초대가 만료됐어요"
        }
    }

    var lines: [String] {
        switch self {
        case .invite:
            [
                "1. 「가족 초대하기」를 눌러 초대 코드를 만들어요.",
                "2. 코드를 가족에게 보내요. 가족은 콜록 앱 설정의 「초대 코드 입력」에 코드를 넣어요.",
                "3. 연결되면 여기서 바로 전화할 수 있어요."
            ]
        case .waiting:
            ["가족이 콜록 앱 설정의 「초대 코드 입력」에 받은 코드를 넣으면 연결돼요."]
        case .expired:
            ["「보낸 초대 보기」에서 새 초대 코드를 만들어 다시 보내주세요."]
        }
    }

    /// 보낸 초대는 구성원 관리 화면에서 본다(코드 보기·새 코드 만들기).
    var primaryActionTitle: String {
        switch self {
        case .invite: "가족 초대하기"
        case .waiting, .expired: "보낸 초대 보기"
        }
    }

    static let codeEntryTitle = "초대 코드 입력"
}
