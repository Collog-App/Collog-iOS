//
//  OnboardingAccountActions.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import SwiftUI

struct OnboardingAccountActions: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsAccount = false

    var body: some View {
        HStack {
            Button("계정 관리") { showsAccount = true }
            Spacer()
            Button("로그아웃") {
                Task { await environment.signOut() }
            }
        }
        .pretendardStyle(.semiBold, 14, .gray800)
        .sheet(isPresented: $showsAccount) {
            AccountSettingsView()
        }
    }
}
