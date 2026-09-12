import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = LoginViewModel()
    @FocusState private var isNameFocused: Bool

    var onSignedIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x6) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("Apple 계정으로 시작하기")
                        .headline_02(.gray900)
                    Text("역할을 선택하고 가족과 통화를 시작하세요.")
                        .body_02_medium(.gray800)
                }

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("역할")
                        .caption_01_medium(.gray800)
                    Picker("역할", selection: $viewModel.role) {
                        ForEach(UserRoleOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("가족에게 표시할 이름")
                        .caption_01_medium(.gray800)
                    TextField("비워두면 Apple 계정 이름을 사용해요", text: $viewModel.name)
                        .pretendardStyle(.medium, 16)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isNameFocused = false }
                        .padding(.horizontal, Spacing.x4)
                        .frame(height: 52)
                        .background(
                            Color.gray00,
                            in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        )
                }
                .disabled(viewModel.isSubmitting)

                if let errorMessage = viewModel.errorMessage ?? environment.session.storageError {
                    Text(errorMessage)
                        .caption_01_medium(.red500)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SignInWithAppleButton(.continue) { request in
                    isNameFocused = false
                    viewModel.configure(request)
                } onCompletion: { result in
                    Task {
                        if await viewModel.complete(result, using: environment) {
                            onSignedIn()
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Radius.btnSmall))
                .disabled(!viewModel.canSignIn)

                if viewModel.isLoadingChallenge || viewModel.isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if !viewModel.canSignIn {
                    Button("로그인 다시 준비하기") {
                        Task { await viewModel.prepareChallenge(using: environment) }
                    }
                    .frame(maxWidth: .infinity)
                }

                guestButton
                    .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Color.gray50
                .ignoresSafeArea()
                .onTapGesture { isNameFocused = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isNameFocused = false }
            }
        }
        .task {
            await viewModel.prepareChallenge(using: environment)
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                await viewModel.refreshChallengeIfNeeded(using: environment)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshChallengeIfNeeded(using: environment) }
            }
        }
    }

    private var guestButton: some View {
        VStack(spacing: Spacing.x2) {
            Button {
                isNameFocused = false
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
}

#Preview {
    LoginView {}
        .environment(AppEnvironment())
}
