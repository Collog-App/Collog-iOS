//
//  FamilyMembersSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

/// 구성원 줄에서 할 수 있는 삭제. 서버 규칙: 대기 중 초대는 구성원 누구나,
/// 연결된 구성원은 가족을 만든 사람이나 본인(나가기)만 지운다.
enum FamilyMemberRemoval: Equatable {
    case invitation
    case member
    case leave

    /// `canRemove`는 서버가 구성원마다 알려 준 값. 나 혼자뿐인 가족에서는 나가기를 보이지 않는다.
    static func resolve(
        isGuest: Bool, canRemove: Bool, memberUserId: String?, userId: String?, hasOtherConnectedMember: Bool
    ) -> Self? {
        guard !isGuest, canRemove else { return nil }
        guard let memberUserId else { return .invitation }
        guard memberUserId == userId else { return .member }
        return hasOtherConnectedMember ? .leave : nil
    }

    var actionTitle: String { self == .leave ? "가족에서 나가기" : "삭제" }

    var confirmTitle: String { self == .leave ? "나가기" : "삭제" }

    func confirmationTitle(name: String) -> String {
        switch self {
        case .invitation: "\(name)님에게 보낸 초대를 삭제할까요?"
        case .member: "\(name)님을 가족에서 삭제할까요?"
        case .leave: "가족에서 나갈까요?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .invitation: "보낸 초대 코드는 더 이상 쓸 수 없어요."
        case .member: "서로 전화하거나 기록을 볼 수 없게 돼요. 다시 함께하려면 새로 초대해야 해요."
        case .leave: "가족과 서로 전화하거나 기록을 볼 수 없게 돼요. 다시 함께하려면 새로 초대받아야 해요."
        }
    }
}

struct FamilyMembersSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var members: [ManagedFamilyMember] = []
    @State private var isLoading = true
    @State private var showsInvitation = false
    @State private var selectedInvitation: FamilyInvitation?
    @State private var errorText: String?
    @State private var serverAllowsInvitations = false
    @State private var showsInvitationCode = false
    @State private var families: [FamilySummary] = []
    @State private var removalRequest: RemovalRequest?
    @State private var isRemoving = false

    private var canInvite: Bool {
        FamilyInvitationAccess.canInvite(
            isGuest: environment.settings.isGuestMode,
            hasFamily: environment.session.familyId != nil,
            serverAllowsInvitations: serverAllowsInvitations
        )
    }

    private var canEnterCode: Bool {
        !isLoading && FamilyInvitationAccess.canEnterCode(
            isGuest: environment.settings.isGuestMode,
            memberUserIds: members.map(\.userId),
            userId: environment.session.user?.id
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                if families.count > 1 {
                    Picker("가족 선택", selection: Binding(
                        get: { environment.session.familyId ?? "" },
                        set: { familyId in Task { await selectFamily(familyId) } }
                    )) {
                        ForEach(families) { family in
                            Text(family.name).tag(family.id)
                        }
                    }
                    .disabled(isLoading)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("함께 연결된 가족")
                        .subtitle_01(.gray900)

                    Spacer(minLength: Spacing.x3)

                    Text("\(members.count)명")
                        .body_03_medium(.gray700)
                }

                if isLoading {
                    loadingRows
                } else {
                    VStack(spacing: Spacing.x2) {
                        ForEach(members) { member in
                            memberRow(member)
                        }
                    }
                }

                if let errorText {
                    Text(errorText).body_03_medium(.red500)
                    Button("다시 시도") { Task { await load() } }
                }

                if canInvite {
                    Button {
                        showsInvitation = true
                    } label: {
                        HStack(spacing: Spacing.x2) {
                            Icon(name: "plus", size: 16, weight: .semibold, color: .greenDark)
                            Text("가족 초대하기")
                                .body_02_semibold(.greenDark)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.btnSmall)
                                .stroke(Color.green200, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if canEnterCode {
                    Button { showsInvitationCode = true } label: {
                        Text("초대 코드 입력")
                            .body_02_semibold(.greenDark)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "가족 구성원 관리")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .sheet(isPresented: $showsInvitationCode) {
            InvitationAcceptSheet {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showsInvitation) {
            FamilyInvitationSheet {
                Task { await load() }
            }
            .environment(environment)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedInvitation) { invitation in
            ExistingInvitationSheet(invitation: invitation) {
                Task { await load() }
            }
            .environment(environment)
            .presentationDetents([.medium])
        }
        .alert(
            removalRequest.map { $0.kind.confirmationTitle(name: $0.member.name) } ?? "",
            isPresented: Binding(
                get: { removalRequest != nil },
                set: { if !$0 { removalRequest = nil } }
            ),
            presenting: removalRequest
        ) { request in
            Button("취소", role: .cancel) {}
            Button(request.kind.confirmTitle, role: .destructive) { Task { await remove(request.member) } }
        } message: { request in
            Text(request.kind.confirmationMessage)
        }
    }

    private var loadingRows: some View {
        VStack(spacing: Spacing.x2) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.gray100)
                    .frame(height: 72)
            }
        }
    }

    private func memberRow(_ member: ManagedFamilyMember) -> some View {
        HStack(spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(member.name)
                    .body_01_semibold(.gray900)

                Text(member.relationTitle)
                    .caption_01_medium(.gray700)
            }

            Spacer(minLength: Spacing.x3)

            Text(member.isConnected ? "가입 완료" : member.invitation?.isExpired == true ? "초대 만료" : "초대 대기")
                .caption_01_semibold(member.isConnected ? .greenDark : .gray700)
            if canInvite, let invitation = member.invitation, !member.isConnected {
                Button { selectedInvitation = invitation } label: {
                    Text("초대 보기").body_03_medium(.greenDark)
                }
            }
            if let removal = removal(for: member) {
                Menu {
                    Button(removal.actionTitle, role: .destructive) {
                        removalRequest = RemovalRequest(member: member, kind: removal)
                    }
                } label: {
                    Icon(name: "ellipsis", size: 20, color: .gray700)
                        .frame(width: 28, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(member.name) 더 보기")
                .disabled(isRemoving)
            }
        }
        .padding(.horizontal, Spacing.x4)
        .frame(height: 72)
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        serverAllowsInvitations = false
        defer { isLoading = false }
        if environment.settings.isGuestMode {
            members = environment.family.contacts.map(ManagedFamilyMember.init(contact:))
            return
        }

        let userId = environment.session.user?.id
        do {
            let available = try await environment.api.families()
            guard environment.session.user?.id == userId else { return }
            families = available
            if !available.contains(where: { $0.id == environment.session.familyId }), let first = available.first {
                try environment.session.joinFamily(first.id)
                environment.family.reset()
                await environment.family.refresh(using: environment)
            }
            guard let familyId = environment.session.familyId else {
                members = []
                return
            }
            let remote: FamilyMembersResponse
            do {
                remote = try await environment.api.familyMembers(familyId: familyId)
            } catch let error as APIError where error.isForbidden {
                // 내가 나갔거나 구성원에서 삭제되어 서버가 이 가족을 막으면 가족 없음으로 되돌린다
                guard environment.session.user?.id == userId,
                      try environment.session.dropRevokedFamily(familyId, available: available) else { throw error }
                environment.family.reset()
                await environment.family.refresh(using: environment)
                members = []
                return
            }
            guard environment.session.user?.id == userId, environment.session.familyId == familyId else { return }
            members = remote.members.map(ManagedFamilyMember.init(member:))
            serverAllowsInvitations = remote.canInvite ?? true
        } catch {
            guard environment.session.user?.id == userId else { return }
            errorText = error.localizedDescription
        }
    }

    private func removal(for member: ManagedFamilyMember) -> FamilyMemberRemoval? {
        let userId = environment.session.user?.id
        return .resolve(
            isGuest: environment.settings.isGuestMode,
            canRemove: member.canRemove,
            memberUserId: member.userId,
            userId: userId,
            hasOtherConnectedMember: members.contains { $0.userId != nil && $0.userId != userId }
        )
    }

    private func remove(_ member: ManagedFamilyMember) async {
        guard !isRemoving, let familyId = environment.session.familyId else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await environment.api.removeFamilyMember(familyId: familyId, memberId: member.id)
            Haptics.commit()
            await load()
            await environment.family.refresh(using: environment)
        } catch {
            // 권한이 없으면(403) 서버가 알려 준 이유를 그대로 보인다
            errorText = error.localizedDescription
        }
    }

    private func selectFamily(_ familyId: String) async {
        guard !isLoading, families.contains(where: { $0.id == familyId }),
              familyId != environment.session.familyId else { return }
        do {
            try environment.session.joinFamily(familyId)
            environment.family.reset()
            members = []
            await load()
            await environment.family.refresh(using: environment)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct ManagedFamilyMember: Identifiable {
    let id: String
    let userId: String?
    let name: String
    let relation: String
    let isConnected: Bool
    let invitation: FamilyInvitation?
    let canRemove: Bool

    init(contact: FamilyContact) {
        id = contact.id
        userId = contact.userId
        name = contact.name
        relation = contact.relation
        isConnected = true
        invitation = nil
        canRemove = false
    }

    init(member: FamilyMember) {
        id = member.id
        userId = member.userId
        name = member.name
        relation = member.relation
        isConnected = member.userId != nil
        invitation = member.invitation
        // 예전 서버처럼 알려 주지 않으면 일단 보이고, 권한이 없으면 서버가 거절한 이유를 보인다
        canRemove = member.canRemove ?? true
    }

    var relationTitle: String {
        FamilyRelation.title(relation) ?? "가족"
    }
}

private struct RemovalRequest {
    let member: ManagedFamilyMember
    let kind: FamilyMemberRemoval
}


#Preview {
    NavigationStack {
        FamilyMembersSettingsView()
            .environment(AppEnvironment())
    }
}
