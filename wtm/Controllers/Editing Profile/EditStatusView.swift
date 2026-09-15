//
//  EditStatusView.swift
//  wtm?
//

import SwiftUI

struct EditStatusView: View {
    var onSelect: (Status) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("edit status")
                    .font(.wtmLargeTitle)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .accessibilityAddTraits(.isHeader)

                Text("what would you like to change your status to?")
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .padding(.top, 8)

                VStack(spacing: 20) {
                    ForEach(Status.allCases) { status in
                        Button {
                            onSelect(status)
                        } label: {
                            statusRow(for: status)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.wtmBackground)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func statusRow(for status: Status) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: status.iconName)
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(Color(status.iconColorName))
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(status.displayTitle)
                        .font(.wtmBold(34, relativeTo: .title))
                    if let trailing = status.titleTrailing {
                        Text(trailing)
                            .font(.wtmRegular(12, relativeTo: .caption))
                    }
                }
                Text(status.descriptionText)
                    .font(.wtmSubtitle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color("secondaryBlack"))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(status.backgroundColorName))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack {
        EditStatusView()
    }
}
