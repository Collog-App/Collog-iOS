//
//  ViewerProfileHeader.swift
//  collog-ios
//

import SwiftUI

/// 리포트·타임라인 맨 위의 「지금 누구를 보는지」 헤더.
/// 큰 아바타 + 이름 + 관계 태그 + 점. 옆으로 밀거나 옆 사람을 눌러 바꾼다.
/// 가로 스와이프는 이 헤더 영역에서만 사람을 바꾸고, 아래 주차 페이저의 스와이프와는 겹치지 않는다.
struct ViewerProfileHeader: View {
    let subjects: [FamilyContact]
    let selectedId: String?
    let onSelect: (FamilyContact) -> Void

    @Environment(\.viewerAccent) private var accent

    private let centerSize: CGFloat = 88
    private let sideSize: CGFloat = 48
    private let sideWidth: CGFloat = 76

    private var index: Int? { subjects.firstIndex { $0.id == selectedId } }
    private var current: FamilyContact? { index.map { subjects[$0] } }

    private func neighbor(_ delta: Int) -> FamilyContact? {
        guard let index, subjects.indices.contains(index + delta) else { return nil }
        return subjects[index + delta]
    }

    var body: some View {
        if let current {
            VStack(spacing: Spacing.x2) {
                HStack(alignment: .center, spacing: Spacing.x3) {
                    sideSlot(neighbor(-1), arrow: "chevron.left")

                    ViewerAvatar(contact: current, size: centerSize, isRinged: true)

                    sideSlot(neighbor(1), arrow: "chevron.right")
                }

                HStack(spacing: Spacing.x2) {
                    Text(current.name)
                        .pretendard(.bold, 24, .gray900)
                    Text(ViewerProfileHeader.relationText(for: current))
                        .pretendard(.semiBold, 14, .gray00)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(accent.text, in: Capsule())
                }

                if subjects.count > 1 {
                    pageDots
                    Text(hint)
                        .pretendard(.medium, 14, .gray800)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(swipe)
            .animation(.smooth(duration: 0.25), value: selectedId)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(current.name), \(Self.relationText(for: current)) 리포트")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if let next = neighbor(1) { onSelect(next) }
                case .decrement: if let previous = neighbor(-1) { onSelect(previous) }
                @unknown default: break
                }
            }
        }
    }

    private var hint: String {
        if subjects.count == 2, let other = neighbor(1) ?? neighbor(-1) {
            return "옆으로 밀거나 “\(other.name)”를 눌러 바꿔요"
        }
        return "옆으로 밀어서 바꿔요"
    }

    private var pageDots: some View {
        HStack(spacing: Spacing.x2) {
            ForEach(Array(subjects.enumerated()), id: \.element.id) { offset, _ in
                Capsule()
                    .fill(offset == index ? accent.accent : Color.gray400)
                    .frame(width: offset == index ? 22 : 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private func sideSlot(_ contact: FamilyContact?, arrow: String) -> some View {
        if let contact {
            Button {
                select(contact)
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        if arrow == "chevron.left" {
                            Icon(name: arrow, size: 18, weight: .semibold, color: .gray800)
                        }
                        ViewerAvatar(contact: contact, size: sideSize, isRinged: false)
                        if arrow == "chevron.right" {
                            Icon(name: arrow, size: 18, weight: .semibold, color: .gray800)
                        }
                    }
                    Text(contact.name)
                        .pretendard(.semiBold, 14, .gray800)
                        .lineLimit(1)
                }
                .padding(.vertical, Spacing.x2)
                .frame(width: sideWidth)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        .strokeBorder(Color.gray400, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(contact.name) 리포트 보기")
        } else {
            Color.clear.frame(width: sideWidth, height: 1)
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 40, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                if let target = neighbor(dx < 0 ? 1 : -1) { select(target) }
            }
    }

    private func select(_ contact: FamilyContact) {
        onSelect(contact)
    }

    static func relationText(for contact: FamilyContact) -> String {
        if contact.id == TimelineViewModel.selfSubjectId { return "본인" }
        return FamilyRelation.title(contact.relation) ?? "가족"
    }
}

/// 이름 첫 글자를 담은 원형 아바타. 지금 보는 사람은 링이 있고 채워진 색, 아닌 사람은 회색.
struct ViewerAvatar: View {
    let contact: FamilyContact
    let size: CGFloat
    var isRinged = false

    @Environment(\.viewerAccent) private var accent

    private var isSelf: Bool { contact.id == TimelineViewModel.selfSubjectId }

    private var fillColor: Color {
        if isRinged { return accent.accent }
        return Color.gray400
    }

    var body: some View {
        Text(String(contact.name.prefix(1)))
            .pretendard(.bold, size * 0.42, .gray00)
            .frame(width: size, height: size)
            .background(fillColor, in: Circle())
            .overlay {
                if isRinged {
                    Circle()
                        .stroke(accent.accent.opacity(0.28), lineWidth: 4)
                        .padding(-5)
                }
            }
            .accessibilityHidden(true)
    }
}

/// 접힌 상단 바 오른쪽에 계속 남는 작은 「지금 보는 사람」 표시.
struct ViewerBadgeChip: View {
    let name: String

    @Environment(\.viewerAccent) private var accent

    var body: some View {
        HStack(spacing: 6) {
            Text(String(name.prefix(1)))
                .pretendard(.bold, 12, .gray00)
                .frame(width: 22, height: 22)
                .background(accent.accent, in: Circle())
            Text(name)
                .pretendard(.semiBold, 14, accent.text)
        }
        .padding(.leading, 5)
        .padding(.trailing, Spacing.x3)
        .padding(.vertical, 5)
        .background(accent.light, in: Capsule())
        .overlay(Capsule().stroke(accent.border, lineWidth: 1.5))
        .accessibilityLabel("지금 \(name) 리포트를 보고 있어요")
    }
}
