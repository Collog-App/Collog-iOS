//
//  LoginView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case phone
        case code
    }

    var onSignedIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x6) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(headerTitle)
                        .headline_02(.gray900)
                    Text(headerMessage)
                        .body_02_medium(.gray800)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if viewModel.step == .identity {
                    identityFields
                } else {
                    codeFields
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .caption_01_medium(.red500)
                        .fixedSize(horizontal: false, vertical: true)
                }

                primaryButton

                guestButton
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.top, Spacing.x8)
            .padding(.bottom, Spacing.x8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Color.gray50
                .onTapGesture { focusedField = nil }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focusedField = nil }
            }
        }
        .onChange(of: viewModel.step) { _, step in
            if step == .code { focusedField = .code }
        }
    }

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("역할")
                    .caption_01_medium(.gray800)

                Picker("역할", selection: $viewModel.role) {
                    ForEach(UserRoleOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            field(
                title: "이름",
                placeholder: "김콜록",
                text: $viewModel.name,
                keyboard: .default,
                focus: .name
            )
            field(
                title: "전화번호",
                placeholder: "01000000001",
                text: $viewModel.phone,
                keyboard: .numberPad,
                focus: .phone
            )
        }
    }

    private var headerTitle: String {
        viewModel.step == .identity ? "전화번호로 시작하기" : "인증번호를 입력해주세요"
    }

    private var headerMessage: String {
        if viewModel.step == .identity {
            return "가족을 연결하고 통화를 기록하려면 번호가 필요해요."
        }
        return "\(viewModel.phone)로 보낸 6자리 숫자를 입력해주세요."
    }

    private var codeFields: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            field(
                title: "인증번호",
                placeholder: "000000",
                text: $viewModel.code,
                keyboard: .numberPad,
                focus: .code
            )

            Text("개발 서버의 인증번호는 000000이에요")
                .caption_01_medium(.gray700)
        }
    }

    private func field(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focus: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(title)
                .caption_01_medium(.gray800)

            TextField(placeholder, text: text)
                .pretendardStyle(.medium, 16)
                .keyboardType(keyboard)
                .textContentType(contentType(for: focus))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: focus)
                .submitLabel(focus == .name ? .next : .done)
                .onSubmit {
                    focusedField = focus == .name ? .phone : nil
                }
                .padding(.horizontal, Spacing.x4)
                .frame(height: 52)
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
        }
    }

    private var primaryButton: some View {
        Button {
            focusedField = nil
            Task {
                if viewModel.step == .identity {
                    await viewModel.requestCode(using: environment)
                } else if await viewModel.verify(using: environment) {
                    onSignedIn()
                }
            }
        } label: {
            Text(viewModel.step == .identity ? "인증번호 받기" : "확인")
                .body_01_semibold(.gray00)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isEnabled ? Color.greenNormal : Color.gray500,
                    in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var guestButton: some View {
        VStack(spacing: Spacing.x2) {
            Button {
                focusedField = nil
                environment.settings.isGuestMode = true
                onSignedIn()
            } label: {
                Text("가입 없이 둘러보기")
                    .body_02_semibold(.gray800)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                            .stroke(Color.gray300, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("예시 데이터로 앱을 먼저 둘러볼 수 있어요")
                .caption_01_medium(.gray700)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var isEnabled: Bool {
        viewModel.step == .identity ? viewModel.canRequestCode : viewModel.canVerify
    }

    private func contentType(for field: Field) -> UITextContentType? {
        switch field {
        case .name: .name
        case .phone: .telephoneNumber
        case .code: .oneTimeCode
        }
    }
}

#Preview {
    LoginView {}
        .environment(AppEnvironment())
}
