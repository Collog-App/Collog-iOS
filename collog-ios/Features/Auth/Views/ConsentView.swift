//
//  ConsentView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ConsentView: View {
    @Environment(AppEnvironment.self) private var environment

    var onAgreed: () -> Void
    var showsAccountActions = true

    @State private var document: ConsentDocument?
    @State private var agreedItems: Set<String> = []
    @State private var hasReachedEnd = false
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var allAgreed: Bool {
        guard let document else { return false }
        return Set(document.requiredItems).isSubset(of: agreedItems)
    }

    var body: some View {
        ScrollView {
            content
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 8
        } action: { _, reachedEnd in
            if reachedEnd, document != nil, !isLoading { hasReachedEnd = true }
        }
        .id(document?.version)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.gray50)
        .task { await load() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("통화 분석을 사용할까요?")
                    .headline_02(.gray900)
                Text("두 사람 모두 동의한 통화만 녹음하고 분석해요. 동의 없이도 일반 통화는 이용할 수 있어요.")
                    .body_02_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.top, Spacing.x8)

            documentBody

            VStack(alignment: .leading, spacing: Spacing.x3) {
                if let document {
                    ForEach(document.requiredItems, id: \.self) { item in
                        checkRow(item)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .caption_01_medium(.red500)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button { submit(granted: true) } label: {
                    Text(hasReachedEnd ? "동의하고 시작하기" : "끝까지 읽어주세요")
                        .body_01_semibold(.gray00)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            canSubmit ? Color.greenNormal : Color.gray500,
                            in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

                Button("동의 없이 통화 이용하기") { submit(granted: false) }
                    .pretendardStyle(.semiBold, 14, .gray800)
                    .disabled(document == nil || isSubmitting || isLoading)
                    .frame(maxWidth: .infinity)

                if showsAccountActions {
                    OnboardingAccountActions()
                        .disabled(isSubmitting)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.bottom, Spacing.x8)
        }
    }

    private var canSubmit: Bool { hasReachedEnd && allAgreed && !isSubmitting && !isLoading }

    private var documentBody: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            if let document {
                Text(document.fullText)
                    .body_02_medium(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                infoRow("수집 항목", document.collectedItems.joined(separator: ", "))
                infoRow("이용 목적", document.purpose)
                infoRow("보관 기간", document.retentionPeriod)
                infoRow("원본 오디오", document.rawAudioPolicy)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("동의 내용을 불러오지 못했어요.")
                    .body_02_medium(.gray900)
                Button("다시 시도") { Task { await load() } }
            }
        }
        .padding(Spacing.x4)
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.x5)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(title)
                .caption_01_medium(.gray700)
            Text(value)
                .body_03_medium(.gray900)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func checkRow(_ item: String) -> some View {
        Button {
            if agreedItems.contains(item) {
                agreedItems.remove(item)
            } else {
                agreedItems.insert(item)
            }
        } label: {
            HStack(spacing: Spacing.x2) {
                Circle()
                    .fill(agreedItems.contains(item) ? Color.greenNormal : Color.gray400)
                    .frame(width: 20, height: 20)

                Text(ConsentItemLabel.korean(for: item))
                    .body_02_medium(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(agreedItems.contains(item) ? "선택됨" : "선택 안 됨")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        hasReachedEnd = false
        agreedItems = []
        document = nil
        defer { isLoading = false }
        do {
            document = try await environment.api.consentDocument()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit(granted: Bool) {
        guard let document, !isSubmitting else { return }
        guard !granted || canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        let userId = environment.session.user?.id
        Task {
            do {
                _ = try await environment.api.submitConsent(
                    documentVersion: document.version,
                    agreedItems: granted ? Array(agreedItems).sorted() : [],
                    decision: granted ? "GRANT" : "DENY",
                    scrolledToEnd: granted && hasReachedEnd
                )
                guard environment.session.user?.id == userId else {
                    isSubmitting = false
                    return
                }
                onAgreed()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    ConsentView {}
        .environment(AppEnvironment())
}
