//
//  ExtendRequestView.swift
//  wtm?
//
//  The modal for giving an open bored request more time.
//

import SwiftUI

/// Picks how much longer a request should stay open.
///
/// Presented as a modal rather than driven straight off the menu so the expiry
/// it would land on is on screen before anything is written — "another 2 hours"
/// on its own doesn't say whether that's still tonight.
struct ExtendRequestView: View {
    /// When the request expires as things stand. The extra time is added to
    /// this rather than to now, so extending tops up what's left instead of
    /// resetting a request that still had ninety minutes on it.
    let currentExpiry: Date
    /// Called with the new expiry when the checkmark is pressed.
    let onExtend: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: BoredRequestDuration = .hour

    private var newExpiry: Date {
        currentExpiry.addingTimeInterval(amount.seconds)
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold(
                title: "extend",
                subtitle: "the extra time gets added on to what's left.",
                scrolls: false
            ) {
                preview
                amountList
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .plainToolbarSymbol()
                    .accessibilityLabel("cancel")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    // Prominent glass, the same treatment the send button gets
                    // on the recipient picker: this is the one thing the screen
                    // exists to do, so it reads as a filled blue button rather
                    // than another grey glyph.
                    Button {
                        onExtend(newExpiry)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.wtmDarkBlue)
                    .accessibilityLabel("extend")
                }
            }
        }
    }

    /// Before and after, so the choice is made against a clock time rather
    /// than an amount of time.
    private var preview: some View {
        VStack(spacing: 10) {
            timeRow(label: "expires at", date: currentExpiry, emphasised: false)
            Divider()
            timeRow(label: "will expire at", date: newExpiry, emphasised: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.wtmGroupedCard)
        .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cardCornerRadius))
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.top, 16)
        // Rolls the new time over digit by digit as the amount changes, so it's
        // obvious which line the selection is moving.
        .animation(.snappy(duration: 0.2), value: newExpiry)
    }

    @ViewBuilder
    private func timeRow(label: String, date: Date, emphasised: Bool) -> some View {
        HStack {
            Text(label)
                .font(.wtmRegular(16, relativeTo: .body))
                .foregroundStyle(Color.wtmSecondaryLabel)

            Spacer()

            Text(timeText(for: date))
                .font(emphasised ? .wtmBold(22, relativeTo: .title3) : .wtmRegular(18, relativeTo: .body))
                .foregroundStyle(emphasised ? Color.wtmDarkBlue : Color.wtmSecondaryLabel)
                .contentTransition(.numericText())
        }
    }

    /// Adding hours to a late-evening request crosses midnight, and a bare
    /// "12:40 AM" would read as earlier than the time above it rather than
    /// later. Nothing on offer here reaches past tomorrow.
    private func timeText(for date: Date) -> String {
        let time = date.toString(dateFormat: "h:mm a")
        return Calendar.current.isDateInToday(date) ? time : "\(time) tomorrow"
    }

    private var amountList: some View {
        List(BoredRequestDuration.allCases, id: \.rawValue) { option in
            Button {
                amount = option
            } label: {
                HStack {
                    Text(option.extensionLabel)
                        .font(.wtmBold(20, relativeTo: .body))
                        .foregroundStyle(Color.wtmDarkBlue)

                    Spacer()

                    Image(systemName: amount == option ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(amount == option ? Color.wtmDarkBlue : Color.wtmSecondaryLabel)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.wtmBackground)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .accessibilityAddTraits(amount == option ? [.isButton, .isSelected] : .isButton)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.2), value: amount)
    }
}

#Preview {
    ExtendRequestView(currentExpiry: Date(timeIntervalSinceNow: 1800)) { _ in }
}
