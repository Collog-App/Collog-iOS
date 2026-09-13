//
//  FamilyMembersSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

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

    private var canInvite: Bool {
        !environment.settings.isGuestMode && environment.session.user?.role == "CHILD"
            && serverAllowsInvitations
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
                if !environment.settings.isGuestMode, environment.session.user?.role == "PARENT" {
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
            let remote = try await environment.api.familyMembers(familyId: familyId)
            guard environment.session.user?.id == userId, environment.session.familyId == familyId else { return }
            members = remote.members.map(ManagedFamilyMember.init(member:))
            serverAllowsInvitations = remote.canInvite ?? (environment.session.user?.role == "CHILD")
        } catch {
            guard environment.session.user?.id == userId else { return }
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
    let name: String
    let relation: String
    let isConnected: Bool
    let invitation: FamilyInvitation?

    init(contact: FamilyContact) {
        id = contact.id
        name = contact.name
        relation = contact.relation
        isConnected = true
        invitation = nil
    }

    init(member: FamilyMember) {
        id = member.id
        name = member.name
        relation = member.relation
        isConnected = member.userId != nil
        invitation = member.invitation
    }

    var relationTitle: String {
        switch relation {
        case "MOTHER": "어머니"
        case "FATHER": "아버지"
        case "CHILD": "자녀"
        case "PARENT": "부모"
        default: "가족"
        }
    }
}

private struct FamilyInvitationSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relation = "MOTHER"
    @State private var invitationCode: String?
    @State private var shareText: String?
    @State private var isSubmitting = false
    @State private var errorText: String?

    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x5) {
                    Text("초대할 가족")
                        .headline_02(.gray900)

                    if let invitationCode, let shareText {
                        invitationResult(code: invitationCode, shareText: shareText)
                    } else {
                        invitationForm
                    }

                    if let errorText {
                        Text(errorText)
                            .body_03_medium(.red500)
                    }
                }
                .padding(.horizontal, Spacing.x5)
                .padding(.vertical, Spacing.x5)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.gray50)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("완료")
                            .body_02_semibold(.greenDark)
                    }
                }
            }
        }
    }

    private var invitationForm: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            TextField("이름", text: $name)
                .pretendardStyle(.medium, 16)
                .padding(.horizontal, Spacing.x4)
                .frame(height: 52)
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))

            Picker("관계", selection: $relation) {
                Text("어머니").tag("MOTHER")
                Text("아버지").tag("FATHER")
            }
            .pickerStyle(.segmented)

            Button {
                Task { await createInvitation() }
            } label: {
                Text(isSubmitting ? "만드는 중" : "초대 만들기")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        name.isEmpty || isSubmitting ? Color.gray500 : Color.greenNormal,
                        in: RoundedRectangle(cornerRadius: Radius.btnSmall)
                    )
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty || isSubmitting)
        }
    }

    private func invitationResult(code: String, shareText: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("초대 코드")
                .body_03_medium(.gray700)

            Text(code)
                .pretendard(.semiBold, 28, .gray900)
                .textSelection(.enabled)

            ShareLink(item: shareText) {
                Text("초대 내용 공유")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
            }
        }
        .cardSurface()
    }

    private func createInvitation() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }

        guard !environment.settings.isGuestMode, environment.session.user?.role == "CHILD" else { return }

        guard let familyId = environment.session.familyId else { return }
        do {
            let invitation = try await environment.api.createInvitation(
                familyId: familyId,
                name: name,
                relation: relation
            )
            invitationCode = invitation.code
            shareText = invitation.shareText
            onCreated()
            Haptics.commit()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct ExistingInvitationSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @State var invitation: FamilyInvitation
    @State private var replacement: InvitationDTO?
    @State private var isSubmitting = false
    @State private var errorText: String?
    let onUpdated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("가족 초대").headline_02(.gray900)
            if replacement != nil || !invitation.isExpired {
                Text(replacement?.code ?? invitation.code)
                    .pretendard(.semiBold, 28, .gray900)
                    .textSelection(.enabled)
                ShareLink("초대 내용 공유", item: replacement?.shareText ?? invitation.shareText)
            } else {
                Text("초대가 만료됐어요. 새 코드를 만들어 주세요.").body_03_medium(.gray700)
            }
            Button(isSubmitting ? "만드는 중" : "새 초대 코드 만들기") {
                Task { await resend() }
            }
            .disabled(isSubmitting)
            if let errorText { Text(errorText).body_03_medium(.red500) }
        }
        .padding(Spacing.x5)
    }

    private func resend() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            replacement = try await environment.api.resendInvitation(
                invitationId: replacement?.invitationId ?? invitation.invitationId
            )
            onUpdated()
        } catch {
            errorText = error.localizedDescription
            onUpdated()
        }
    }
}

#Preview {
    NavigationStack {
        FamilyMembersSettingsView()
            .environment(AppEnvironment())
    }
}
