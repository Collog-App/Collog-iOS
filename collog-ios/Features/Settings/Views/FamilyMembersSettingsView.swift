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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
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
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "가족 구성원 관리")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .sheet(isPresented: $showsInvitation) {
            FamilyInvitationSheet { member in
                members.append(member)
            }
            .environment(environment)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

            Text(member.isConnected ? "통화 가능" : "초대 대기")
                .caption_01_semibold(member.isConnected ? .greenDark : .gray700)
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
        defer { isLoading = false }
        if environment.settings.isGuestMode {
            members = environment.family.contacts.map(ManagedFamilyMember.init(contact:))
            return
        }

        guard let familyId = environment.session.familyId else { return }
        if let remote = try? await environment.api.members(familyId: familyId) {
            members = remote.map(ManagedFamilyMember.init(member:))
        }
    }
}

private struct ManagedFamilyMember: Identifiable {
    let id: String
    let name: String
    let relation: String
    let isConnected: Bool

    init(contact: FamilyContact) {
        id = contact.id
        name = contact.name
        relation = contact.relation
        isConnected = true
    }

    init(member: FamilyMember) {
        id = member.id
        name = member.name
        relation = member.relation
        isConnected = member.userId != nil
    }

    init(id: String, name: String, relation: String, isConnected: Bool) {
        self.id = id
        self.name = name
        self.relation = relation
        self.isConnected = isConnected
    }

    var relationTitle: String {
        switch relation {
        case "MOTHER": "어머니"
        case "FATHER": "아버지"
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

    let onCreated: (ManagedFamilyMember) -> Void

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

        if environment.settings.isGuestMode {
            let code = String(format: "%06d", Int.random(in: 0...999_999))
            invitationCode = code
            shareText = "콜록 가족 초대 코드 \(code)를 앱에 입력해주세요."
            onCreated(
                ManagedFamilyMember(
                    id: UUID().uuidString,
                    name: name,
                    relation: relation,
                    isConnected: false
                )
            )
            Haptics.commit()
            return
        }

        guard let familyId = environment.session.familyId else { return }
        do {
            let invitation = try await environment.api.createInvitation(
                familyId: familyId,
                name: name,
                relation: relation
            )
            invitationCode = invitation.code
            shareText = invitation.shareText
            onCreated(
                ManagedFamilyMember(
                    id: invitation.invitationId,
                    name: name,
                    relation: relation,
                    isConnected: false
                )
            )
            Haptics.commit()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        FamilyMembersSettingsView()
            .environment(AppEnvironment())
    }
}
