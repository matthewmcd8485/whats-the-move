//
//  OnboardingScaffold.swift
//  wtm?
//
//  The five onboarding screens were five storyboard scenes with byte-identical
//  frames: a full-width centred title at y=71, optional body copy, an optional
//  field at y=308, and a bottom call-to-action at y≈710 made of a label, an
//  `arrow.right` image, and a transparent button laid on top of both.
//
//  This is that layout, once. Every label in those scenes was
//  `textAlignment="center"` across a 358pt-wide frame, so everything here is
//  centred too. What's gone is the absolute positioning: the title and body
//  scroll from the top, the CTA is pinned to the bottom, and the content area
//  flexes. That reproduces the design on every screen size instead of only the
//  390x844 canvas it was drawn on, and lets text grow with Dynamic Type rather
//  than clipping.
//

import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    var footnote: String?
    let actionTitle: String

    /// Disables the CTA — used while a network call is in flight or when input
    /// is incomplete.
    var isActionEnabled: Bool = true
    /// Swaps the CTA for a progress indicator. Replaces the old pattern of
    /// toggling `isHidden` on three separate outlets.
    var isBusy: Bool = false

    var background: Color = .wtmBackground
    var titleFont: Font = .wtmScreenTitle
    var titleColor: Color = .wtmDarkBlue
    var actionColor: Color = .wtmDarkBlue

    @ViewBuilder var content: Content
    let action: () -> Void

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // GeometryReader so the scroll content can be stretched to at
                // least the visible height. Without that, the empty area under
                // short content isn't part of any view and so can't receive the
                // tap that dismisses the keyboard.
                GeometryReader { proxy in
                    ScrollView {
                        scrollContent
                            .frame(minHeight: proxy.size.height, alignment: .top)
                            .contentShape(.rect)
                            // Tapping blank space dismisses the keyboard, the
                            // way the old UITapGestureRecognizer on each
                            // controller's root view did. Taps that land on the
                            // field or a button are consumed by those views, so
                            // this only fires on empty space.
                            .onTapGesture(perform: dismissKeyboard)
                    }
                    // Only scrolls when the content actually overflows, so short
                    // steps still feel like static screens.
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                }

                callToAction
            }
        }
    }

    private var scrollContent: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(.wtmFootnote)
                    .foregroundStyle(Color.wtmTertiaryLabel)
            }
        }
        .multilineTextAlignment(.center)
        // Let long / scaled text wrap instead of truncating.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    private var callToAction: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .tint(actionColor)
                } else {
                    Text(actionTitle)
                        .font(.wtmAction)
                        .multilineTextAlignment(.center)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        // Decorative: the button's own label already says
                        // where it goes.
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(actionColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: WTMLayout.ctaHeight)
            .contentShape(.rect)
        }
        .disabled(!isActionEnabled || isBusy)
        .opacity(isActionEnabled || isBusy ? 1 : 0.4)
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.bottom, 12)
        .animation(.snappy, value: isBusy)
    }
}

// MARK: - Keyboard

/// Resigns whatever is currently first responder.
///
/// SwiftUI has no dedicated "dismiss the keyboard" action — the documented
/// route is setting a `FocusState` back to false. That doesn't work here
/// because the phone step's field is a UIKit `PhoneNumberTextField` behind a
/// representable, which SwiftUI's focus system doesn't drive. Asking the
/// responder chain works for both kinds of field.
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

// MARK: - Shared input styling

/// The storyboard drew each onboarding field as a centred 358x34 box. This
/// keeps that look in one place.
struct OnboardingFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.wtmInput)
            .foregroundStyle(Color.wtmDarkBlue)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.wtmSecondaryLabel.opacity(0.4))
                    .frame(height: 1)
            }
    }
}

extension View {
    func onboardingField() -> some View {
        modifier(OnboardingFieldStyle())
    }
}

#Preview("With field") {
    OnboardingScaffold(
        title: "enter your phone number",
        subtitle: nil,
        footnote: "a verification code will be sent to your device.\nstandard SMS messaging rates may apply.",
        actionTitle: "next"
    ) {
        TextField("ex. 123456", text: .constant(""))
            .onboardingField()
    } action: {}
}

#Preview("Busy") {
    OnboardingScaffold(
        title: "check your\nmessages",
        subtitle: "enter the verification code that was just sent to your phone.",
        actionTitle: "log in",
        isBusy: true
    ) {
        EmptyView()
    } action: {}
}
