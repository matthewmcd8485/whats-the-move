//
//  DesignTokens.swift
//  wtm?
//
//  Central definitions for the app's type ramp and palette.
//
//  Two reasons this exists:
//
//  1. Dynamic Type. `.custom(_:size:)` produces a fixed-size font that ignores
//     the user's text-size setting. `.custom(_:size:relativeTo:)` scales with it.
//     Every font here is declared relative to a system text style, so text grows
//     for people who need it without each view hardcoding a point size.
//
//  2. Compile-time checked colors. `Color("darkBlueOnLight")` fails silently at
//     runtime if the asset is renamed or misspelled. Naming them once here means
//     a typo is a build error instead of an invisible black rectangle.
//
//  New screens should use these rather than inline `.custom(...)` / `Color("...")`.
//

import SwiftUI

// MARK: - Typography

extension Font {
    /// The app's display face, in its three shipped weights.
    enum WTM {
        static let bold = "SuperBasic-Bold"
        static let regular = "SuperBasic-Regular"
        static let thin = "SuperBasic-Thin"
    }

    static func wtmBold(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(WTM.bold, size: size, relativeTo: style)
    }

    static func wtmRegular(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(WTM.regular, size: size, relativeTo: style)
    }

    static func wtmThin(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(WTM.thin, size: size, relativeTo: style)
    }

    // MARK: Semantic roles
    //
    // Sizes match the existing storyboard/SwiftUI screens so the app looks the
    // same; the `relativeTo:` anchor is what's new.

    /// Oversized hero wordmark, e.g. "wtm?" on the welcome screen.
    static let wtmHero = wtmBold(100, relativeTo: .largeTitle)
    /// Standard screen heading, e.g. "enter your phone number".
    static let wtmScreenTitle = wtmBold(35, relativeTo: .largeTitle)
    /// Heading on screens that already use a 48pt title (friends, settings).
    static let wtmLargeTitle = wtmBold(48, relativeTo: .largeTitle)
    /// Explanatory copy under a title.
    static let wtmSubtitle = wtmRegular(15, relativeTo: .subheadline)
    /// Lighter variant of the subtitle used on some onboarding steps.
    static let wtmSubtitleThin = wtmThin(13, relativeTo: .footnote)
    /// Small print under an input, e.g. character limits.
    static let wtmFootnote = wtmThin(14, relativeTo: .caption)
    /// Primary call-to-action label.
    static let wtmAction = wtmBold(25, relativeTo: .title3)
    /// Secondary action / large tappable row label.
    static let wtmActionSecondary = wtmBold(28, relativeTo: .title3)
    /// Text entered by the person using the app.
    static let wtmInput = wtmThin(25, relativeTo: .title3)
    /// Welcome-screen tagline.
    static let wtmTagline = wtmThin(22, relativeTo: .title3)
    /// Emphasised end of the welcome-screen tagline.
    static let wtmTaglineStrong = wtmBold(29, relativeTo: .title2)
}

// MARK: - Palette

extension Color {
    static let wtmBackground = Color("backgroundColors")
    static let wtmSecondaryBackground = Color("secondaryBackgroundColors")
    static let wtmGroupedCard = Color("groupedCardBackground")

    static let wtmDarkBlue = Color("darkBlueOnLight")
    static let wtmLightBlue = Color("lightBlueOnLight")

    static let wtmSecondaryLabel = Color("secondaryLabelColors")
    static let wtmTertiaryLabel = Color("tertiaryLabelColors")

    static let wtmDarkGreen = Color("darkGreenOnLight")
    static let wtmDarkYellow = Color("darkYellowOnLight")
    static let wtmDarkRed = Color("darkRedOnLight")
}

// MARK: - Layout

/// Shared spacing so screens line up with each other. The storyboard used a
/// 16pt side margin on a 390pt canvas (a 358pt content width); keeping the
/// margin and letting the width flex reproduces the design on every device.
enum WTMLayout {
    static let sideMargin: CGFloat = 16
    static let ctaHeight: CGFloat = 53
    static let cornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
}
