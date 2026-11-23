//
//  FamilyConnectGuideCardView.swift
//  collog-ios
//

import SwiftUI

/// 홈의 가족 연결 안내(피그마 없음, 기존 카드 모양). 아직 아무와도 연결되지 않은 사람에게
/// 초대하는 법과 받은 초대 코드를 넣는 곳을 알려 준다. 초대·코드 입력·구성원 관리는 기존 화면을 그대로 연다.
struct FamilyConnectGuideCardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsInvitation = false
    @State private var showsInvitationCode = false
    @State private var showsFamilyMembers = false

    let guide: FamilyConnectGuide
    /// 초대를 만들었거나 가족에 들어가 가족 상태가 바뀌었을 때.
    let onChanged: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(guide.title)
                    .subtitle_02(.gray900)

                ForEach(guide.lines, id: \.self) { line in
                    Text(line)
                        .body_02_medium(.gray800)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: Spacing.x2) {
                Button(action: performPrimaryAction) {
                    Text(guide.primaryActionTitle)
                        .body_01_semibold(.gray00)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
                }
                .buttonStyle(.plain)

                Button {
                    showsInvitationCode = true
                } label: {
                    Text(FamilyConnectGuide.codeEntryTitle)
                        .body_02_semibold(.greenDark)
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
        }
        .cardSurface()
        .sheet(isPresented: $showsInvitation) {
            FamilyInvitationSheet {
                Task { await onChanged() }
            }
            .environment(environment)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsInvitationCode) {
            InvitationAcceptSheet {
                Task { await onChanged() }
            }
        }
        // 보낸 초대 코드는 구성원 관리의 「초대 보기」에 있다
        .sheet(isPresented: $showsFamilyMembers, onDismiss: { Task { await onChanged() } }) {
            NavigationStack { FamilyMembersSettingsView() }
                .presentationDragIndicator(.visible)
        }
    }

    private func performPrimaryAction() {
        switch guide {
        case .invite: showsInvitation = true
        case .waiting: showsFamilyMembers = true
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.x4) {
            FamilyConnectGuideCardView(guide: .invite, onChanged: {})
            FamilyConnectGuideCardView(guide: .waiting, onChanged: {})
        }
        .padding()
    }
    .background(Color.gray50)
    .environment(AppEnvironment())
}
