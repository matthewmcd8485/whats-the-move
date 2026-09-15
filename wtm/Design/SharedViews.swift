//
//  SharedViews.swift
//  wtm?
//
//  Pieces that several rebuilt screens need. Most of the storyboard scenes were
//  variations on the same three things: a big title with optional body copy, a
//  circular profile image loaded from Firebase Storage, and a coloured status
//  card. Defining them once keeps the screens short and consistent.
//

import SwiftUI
import FirebaseStorage

// MARK: - Screen scaffold

/// The heading treatment every non-onboarding screen shares: a 48pt title at
/// the top left with optional centred body copy beneath it.
struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    var scrolls: Bool = true

    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if scrolls {
                ScrollView {
                    stack
                        .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                stack
            }
        }
        .background(Color.wtmBackground)
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.wtmLargeTitle)
                .foregroundStyle(Color.wtmDarkBlue)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, WTMLayout.sideMargin)

            if let subtitle {
                // Aligned with the title rather than centred. The two were
                // disagreeing — a leading 48pt title with centred body copy
                // under it — which read as a mistake rather than a choice.
                Text(subtitle)
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 4)
            }

            content
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty / loading states

/// The "loading..." and "nobody here" labels the storyboard scenes toggled with
/// `isHidden` and alpha animations.
struct CenteredMessage: View {
    let text: String
    var font: Font = .wtmBold(25, relativeTo: .title2)
    var color: Color = .wtmSecondaryLabel

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
    }
}

// MARK: - Avatar

/// A person's profile image.
///
/// Firestore already stores each account's download URL on the user document,
/// so when a caller has a `User` it passes `urlString` and this goes straight
/// to `AsyncImage` — no Storage round-trip at all. Only callers that have just
/// a uid (a friend request row, say) fall back to resolving it, and that result
/// is memoised for the process so revisiting a screen doesn't re-resolve.
///
/// Previously every appearance cleared the image, awaited `downloadURL()`, then
/// loaded — which is why reopening a profile flashed blank, then a spinner,
/// then the photo. Combined with `AsyncImage`'s HTTP cache on iOS 27, a second
/// visit now paints immediately.
struct RemoteAvatarView: View {
    let uid: String
    /// The download URL from the user document, when the caller has it.
    var urlString: String?
    var size: CGFloat = 150
    var fallbackSymbol = "person.circle"

    @State private var resolved: URL?
    @State private var didFailToResolve = false

    /// Process-wide uid -> URL memo for the resolve fallback.
    @MainActor
    private static var resolvedURLs: [String: URL] = [:]
    /// uids known to have no stored picture, so misses aren't retried.
    @MainActor
    private static var unavailable: Set<String> = []

    /// Placeholder strings the backend writes when there's no picture.
    private static let placeholders: Set<String> = [
        "No profile picture yet", "No profile image yet", "no url", "user deleted", ""
    ]

    private var directURL: URL? {
        guard let urlString, !Self.placeholders.contains(urlString) else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        Group {
            if let url = directURL ?? resolved {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .task(id: uid) { await resolveIfNeeded() }
    }

    private var placeholder: some View {
        Image(systemName: didFailToResolve ? "person.crop.circle.badge.questionmark" : fallbackSymbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.wtmDarkBlue)
    }

    private func resolveIfNeeded() async {
        // Nothing to do when the caller handed us a usable URL.
        guard directURL == nil else { return }

        // A caller that supplied one of the backend's "no picture" markers has
        // told us there's nothing to fetch — going to Storage would just 404
        // on every appearance. Only resolve when no string was supplied at all.
        if let urlString, Self.placeholders.contains(urlString) {
            didFailToResolve = true
            return
        }

        if let memoised = Self.resolvedURLs[uid] {
            resolved = memoised
            return
        }
        if Self.unavailable.contains(uid) {
            didFailToResolve = true
            return
        }

        let reference = Storage.storage().reference()
            .child("profile images")
            .child("\(uid) - profile image.png")

        guard let url = try? await reference.downloadURL() else {
            // Remember the miss so we don't re-request on every appearance.
            Self.unavailable.insert(uid)
            didFailToResolve = true
            return
        }
        Self.resolvedURLs[uid] = url
        resolved = url
    }
}

// MARK: - Status card

/// The coloured availability card shown on the friend detail and add-friend
/// screens. `Status` already carries the palette names and the "stfu!" display
/// title, so the card just reads them off the case.
struct StatusCard: View {
    let status: Status
    let substatus: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundStyle(Color(status.iconColorName))

            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayTitle)
                    .font(.wtmBold(34, relativeTo: .title))
                Text(substatus)
                    .font(.wtmSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color("secondaryBlack"))

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(status.backgroundColorName))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Primary button

/// The full-width dark blue action button used across the rebuilt screens.
struct PrimaryActionButton: View {
    let title: String
    var background: Color = .wtmDarkBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.wtmBold(20, relativeTo: .title3))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WTMLayout.ctaHeight)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cornerRadius))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Report / block

/// Report-or-block, shared by the friend detail and add-friend screens. Both
/// previously carried three near-identical nested UIAlertControllers.
struct ReportUserButton: View {
    let uid: String
    let name: String
    /// Called after a successful report or block so the caller can navigate away.
    let onFinished: () -> Void

    @State private var showBlockConfirm = false
    @State private var showReportConfirm = false
    @State private var showBlocked = false
    @State private var failureMessage: String?
    @State private var showFailure = false

    var body: some View {
        Menu {
            Button("report user", systemImage: "flag") { showReportConfirm = true }
            Button("block user", systemImage: "hand.raised.slash") { showBlockConfirm = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .plainToolbarSymbol()
        .accessibilityLabel("user options")
        .confirmationDialog("block user", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("block user", role: .destructive) { block() }
            Button("oops, cancel", role: .cancel) {}
        } message: {
            Text("are you sure?\n\nany groups you are in with this person will NOT be deleted.\n\nthis action cannot be undone.")
        }
        .confirmationDialog("report user", isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button("report user", role: .destructive) { report() }
            Button("oops, cancel", role: .cancel) {}
        } message: {
            Text("are you sure? this action cannot be undone.")
        }
        .alert("user blocked", isPresented: $showBlocked) {
            Button("yeah, me too") { onFinished() }
        } message: {
            Text("you have successfully blocked this person.\n\nsorry they were mean to you or whatever.")
        }
        .alert("something went wrong", isPresented: $showFailure) {
            Button("okay", role: .cancel) {}
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private func block() {
        Task {
            if await DatabaseManager.shared.blockUser(uidToBlock: uid) {
                showBlocked = true
            } else {
                failureMessage = "there was an error when blocking the user. please try again."
                showFailure = true
            }
        }
    }

    private func report() {
        Task {
            let date = Date().toString(dateFormat: "yyyy-MM-dd 'at' HH:mm:ss")
            if await ReportingManager.shared.reportUser(uid: uid, name: name, date: date) {
                onFinished()
            } else {
                failureMessage = "something went wrong when reporting the user. please try again."
                showFailure = true
            }
        }
    }
}

// MARK: - Alphabetical sectioning

/// One A–Z bucket of a long list, used to drive `sectionIndexLabel`.
struct IndexedSection<Item>: Identifiable {
    /// The index letter, or "#" for names that don't start with one.
    let id: String
    let items: [Item]
}

/// Buckets items by the first letter of `name` so a list can offer the
/// Contacts-style index scrubber. Names that don't begin with a letter land in
/// a trailing "#" section.
func alphabeticalSections<Item>(
    _ items: [Item],
    name: (Item) -> String
) -> [IndexedSection<Item>] {
    let buckets = Dictionary(grouping: items) { item -> String in
        // Fold diacritics so "Émile" indexes under E rather than getting its
        // own É section, which is what Contacts does.
        let folded = name(item)
            .trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive], locale: .current)
        guard let first = folded.first, first.isLetter else { return "#" }
        return String(first).uppercased()
    }

    return buckets
        .map { IndexedSection(id: $0.key, items: $0.value) }
        .sorted { lhs, rhs in
            // "#" sorts last so the alphabet reads normally.
            if lhs.id == "#" { return false }
            if rhs.id == "#" { return true }
            return lhs.id < rhs.id
        }
}

/// Header for an alphabetical section.
struct SectionLetterHeader: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.wtmBold(13, relativeTo: .caption))
            .foregroundStyle(Color.wtmSecondaryLabel)
    }
}

// MARK: - Compact person row

/// A single-line person row for the long friend and member lists.
///
/// The status used to be spelled out on a second line under the name, but the
/// leading icon already encodes it — available, busy, do-not-disturb, blocked
/// and deleted each have their own glyph — so the subtitle was saying the same
/// thing twice and doubling the row height.
struct CompactPersonRow: View {
    let user: User
    /// What sits at the trailing edge. Rows that push a screen get a chevron;
    /// rows in a multi-select picker get a checkbox instead.
    var accessory: Accessory = .chevron

    enum Accessory {
        case chevron
        case checkbox(isOn: Bool)
        case none
    }

    private var isBlocked: Bool {
        ReportingManager.shared.userIsBlocked(theirUID: user.uid)
            || ReportingManager.shared.userBlockedYou(theirUID: user.uid)
    }

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 24, height: 24)

            Text(user.uid == SecureStorage.uid ? "you" : user.name.lowercased())
                .font(.wtmBold(18, relativeTo: .body))
                .foregroundStyle(Color.wtmDarkBlue)
                .lineLimit(1)

            Spacer(minLength: 8)

            trailingAccessory
        }
        .frame(minHeight: 38)
        .contentShape(.rect)
        // The glyph carries the status, so say it out loud for VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(accessibilityTraits)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        case .checkbox(let isOn):
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(isOn ? Color.wtmDarkBlue : Color.wtmSecondaryLabel)
        case .none:
            EmptyView()
        }
    }

    private var accessibilityTraits: AccessibilityTraits {
        if case .checkbox(let isOn) = accessory, isOn {
            return [.isButton, .isSelected]
        }
        return .isButton
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if user.name == "user deleted" {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.gray)
            } else if isBlocked {
                Image(systemName: "hand.raised.slash")
                    .foregroundStyle(.red)
            } else {
                let status = Status(stored: user.status)
                Image(systemName: status.iconName)
                    .foregroundStyle(Color(status.iconColorName))
            }
        }
        .font(.system(size: 19, weight: .regular))
    }

    private var accessibilityDescription: String {
        let name = user.uid == SecureStorage.uid ? "you" : user.name.lowercased()
        if user.name == "user deleted" { return "\(name), no status available" }
        if isBlocked { return "\(name), blocked" }
        return "\(name), \(Status(stored: user.status).rawValue)"
    }
}

// MARK: - Toolbar tinting

extension View {
    /// Draws a bar button's symbol monochrome instead of in the app's blue.
    ///
    /// Toolbar buttons take their symbol colour from the inherited tint, and
    /// every navigation stack here sets that to `.wtmDarkBlue` — which is right
    /// for back chevrons and controls, but made every bar glyph blue where the
    /// system draws them in the label colour.
    ///
    /// Not for `.glassProminent` buttons: there the tint is the button's fill,
    /// and those are meant to be blue.
    func plainToolbarSymbol() -> some View {
        tint(.primary)
    }
}

// MARK: - Artwork dimming

extension View {
    /// The uniform dim laid over activity artwork that white text sits on.
    ///
    /// One lever for all three places the artwork appears — the activity
    /// picker, the requests list and a request's header — so they can't drift
    /// apart. It needs to be this heavy because the photos range from nearly
    /// black to wide-open midday sky, and the floor has to be dark enough for
    /// the brightest of them. Callers still add a gradient where their text
    /// actually sits; this is the base, not the whole job.
    func dimmedArtwork(_ opacity: Double = 0.5) -> some View {
        overlay { Color.black.opacity(opacity) }
    }
}

// MARK: - Status parsing

extension Status {
    /// Firestore stores the status as a free-form string; anything unexpected
    /// is treated as do-not-disturb, which is how the old controllers' if/else
    /// chains behaved.
    init(stored: String) {
        self = Status(rawValue: stored) ?? .doNotDisturb
    }
}



