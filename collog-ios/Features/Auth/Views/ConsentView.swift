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

    @State private var document: ConsentDocument?
    @State private var agreedItems: Set<String> = []
    @State private var hasReachedEnd = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var allAgreed: Bool {
        guard let document else { return false }
        return Set(document.requiredItems).isSubset(of: agreedItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("분석 동의가 필요해요")
                    .headline_02(.gray900)
                Text("동의한 통화만 분석하고, 원본 음성은 분석 직후 폐기해요.")
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

                Button(action: submit) {
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
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.bottom, Spacing.x8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.gray50)
        .task { await load() }
    }

    private var canSubmit: Bool { hasReachedEnd && allAgreed && !isSubmitting }

    private var documentBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                if let document {
                    Text(document.fullText)
                        .body_02_medium(.gray900)
                        .fixedSize(horizontal: false, vertical: true)

                    infoRow("수집 항목", document.collectedItems.joined(separator: ", "))
                    infoRow("이용 목적", document.purpose)
                    infoRow("보관 기간", document.retentionPeriod)
                    infoRow("원본 오디오", document.rawAudioPolicy)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Spacing.x4)
        }
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.x5)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 8
        } action: { _, reachedEnd in
            if reachedEnd { hasReachedEnd = true }
        }
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

                Text(item)
                    .body_02_medium(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            document = try await environment.api.consentDocument()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() {
        guard let document else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await environment.api.submitConsent(
                    documentVersion: document.version,
                    agreedItems: Array(agreedItems)
                )
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
