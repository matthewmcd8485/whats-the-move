//
//  WTMApp.swift
//  wtm?
//
//  The app entry point.
//
//  This replaces Main.storyboard, SceneDelegate, LoadingViewController and
//  TabBarController. AppDelegate stays — Firebase Messaging and the
//  notification categories are registered through it — but it's now attached
//  with `UIApplicationDelegateAdaptor` rather than being `@main` itself.
//

import SwiftUI

@main
struct WTMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Drives which of the three top-level states is on screen.
    @State private var session = SessionModel()
    /// Shared with `AppDelegate`, which is where notification responses land.
    @State private var deepLinks = DeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(deepLinks)
                .tint(.wtmDarkBlue)
        }
    }
}

// MARK: - Session state

@Observable
@MainActor
final class SessionModel {
    enum Phase: Equatable {
        case launching
        case onboarding
        case signedIn
    }

    var phase: Phase = .launching

    /// Set once launch work has been running long enough that the connection is
    /// probably the problem, so the launch screen can offer a retry instead of
    /// spinning at someone indefinitely.
    var launchDidTimeOut = false

    /// How long to wait before assuming the network isn't coming back. Long
    /// enough to cover a slow-but-working connection — every launch does four
    /// Firestore round-trips — short enough not to feel like a hang.
    private static let launchTimeout: Duration = .seconds(12)

    private var launchTask: Task<Void, Never>?

    /// Decides where to send the person on launch and warms the caches the
    /// signed-in screens expect. Replaces LoadingViewController.
    ///
    /// Safe to call again: a retry abandons the attempt already in flight
    /// rather than racing it.
    func start() async {
        launchTask?.cancel()
        launchDidTimeOut = false

        let work = Task { await self.applyResolvedPhase() }
        launchTask = work

        let timeout = Task {
            try? await Task.sleep(for: Self.launchTimeout)
            guard !Task.isCancelled else { return }
            Log.ui.info("launch work timed out; offering a retry")
            launchDidTimeOut = true
        }

        await work.value
        timeout.cancel()
    }

    private func applyResolvedPhase() async {
        let resolved = await resolvePhase()
        // An abandoned attempt finishing late mustn't move the app: the
        // Firestore calls below don't answer to cancellation, so a retry's
        // predecessor can still come back long after it was replaced.
        guard !Task.isCancelled else { return }
        phase = resolved
    }

    private func resolvePhase() async -> Phase {
        // A missing uid means signed out even if the flag says otherwise; that
        // can happen when the Keychain migration couldn't read the legacy
        // UserDefaults value.
        guard UserDefaults.standard.bool(forKey: "loggedIn"),
              let uid = SecureStorage.uid else {
            return .onboarding
        }

        async let friends: Void = Self.refreshFriends(uid: uid)
        async let groups: Void = Self.refreshGroups(uid: uid)
        async let cache: Void = LocalCacheManager.shared.refreshFromNetwork(myUID: uid)
        async let blockedSynced = DatabaseManager.shared.updateBlockedUsersList(uid: uid)

        let (_, _, _, synced) = await (friends, groups, cache, blockedSynced)

        guard synced else {
            // Without the block lists we can't filter content correctly, so
            // treat it as signed out rather than showing unfiltered people.
            UserDefaults.standard.set(false, forKey: "loggedIn")
            return .onboarding
        }

        await PushManager.refreshRegistration(uid: uid)
        return .signedIn
    }

    /// Clears credentials and returns to onboarding.
    func signOut() {
        // Detach this device from the account being left, or its document goes
        // on holding this device's token and keeps receiving that account's
        // pushes after someone else signs in here.
        if let uid = SecureStorage.uid {
            DatabaseManager.shared.updateFCMToken(uid: uid, newToken: "")
        }
        // Throw the token away too, so the next account gets a fresh one
        // instead of inheriting this one.
        PushManager.discardToken()
        UserDefaults.resetDefaults()
        UserDefaults.standard.set(true, forKey: "launchedBefore")
        LocalCacheManager.shared.wipe()
        phase = .onboarding
    }

    private static func refreshFriends(uid: String) async {
        do {
            let friends = try await DatabaseManager.shared.downloadAllFriends(uid: uid)
            UserDefaults.standard.set(friends.map(\.uid), forKey: "friendsUID")
        } catch {
            Log.database.error("launch — friends: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func refreshGroups(uid: String) async {
        do {
            let groups = try await DatabaseManager.shared.downloadAllGroups(uid: uid)
            UserDefaults.standard.set(groups.map(\.groupID), forKey: "groupsUID")
        } catch {
            Log.database.error("launch — groups: \(error.localizedDescription, privacy: .public)")
        }
    }

}

// MARK: - Root

struct RootView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        switch session.phase {
        case .launching:
            LaunchView(
                showsRetry: session.launchDidTimeOut,
                onRetry: { Task { await session.start() } }
            )
            .task { await session.start() }
        case .onboarding:
            OnboardingFlowView(onFinished: { session.phase = .signedIn })
        case .signedIn:
            MainTabView()
        }
    }
}

/// The screen shown while launch work runs.
///
/// This is what's on screen either side of the handover from the real launch
/// screen, so it's laid out to match `LaunchScreen.storyboard` exactly — same
/// two images, same background colour, same positions — and there's no visible
/// swap. It used to draw "wtm?" in 100pt type with a spinner under it, which
/// shared nothing with the storyboard but the background.
struct LaunchView: View {
    /// Launch work has been running too long to keep waiting silently.
    var showsRetry = false
    var onRetry: () -> Void = {}

    /// The storyboard pinned both images to fixed frames on a 414×896 canvas.
    /// Expressing them as fractions of the height reproduces that layout and
    /// keeps it in the same place on every screen size.
    private enum Storyboard {
        static let sideMargin: CGFloat = 20
        static let logoTop: CGFloat = 144 / 896
        static let logoHeight: CGFloat = 252 / 896
        static let wordmarkTop: CGFloat = 630 / 896
        static let wordmarkHeight: CGFloat = 95 / 896
    }

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height

            ZStack(alignment: .top) {
                Color.wtmLightBlue

                // scaleAspectFill in the storyboard: the artwork is 4:3 and the
                // frame is wider than that, so it crops rather than letterboxes.
                Image("wtm-darkBlueOnLight")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height * Storyboard.logoHeight)
                    .clipped()
                    .padding(.horizontal, Storyboard.sideMargin)
                    .offset(y: height * Storyboard.logoTop)

                Image("textTitle-darkBlueOnLight")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: height * Storyboard.wordmarkHeight)
                    .padding(.horizontal, Storyboard.sideMargin)
                    .offset(y: height * Storyboard.wordmarkTop)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // In the empty band under the wordmark, so nothing the storyboard
            // draws has to move to make room for it.
            .overlay(alignment: .bottom) {
                status
                    .padding(.horizontal, 32)
                    .padding(.bottom, 64)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var status: some View {
        VStack(spacing: 14) {
            if showsRetry {
                Text("this is taking a while.\ncheck your connection?")
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                RetryButton(action: onRetry)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.wtmDarkBlue)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.35), value: showsRetry)
    }
}

/// Takes the spinner's place when launch work stalls.
///
/// It breathes while it waits so it reads as the thing to press, and the arrow
/// turns a full rotation on each tap — a retry that goes on to stall again
/// still has to feel like it did something.
private struct RetryButton: View {
    let action: () -> Void

    @State private var rotations = 0
    @State private var isBreathing = false

    var body: some View {
        Button {
            rotations += 1
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold))
                    .rotationEffect(.degrees(Double(rotations) * 360))
                Text("try again")
                    .font(.wtmBold(20, relativeTo: .title3))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(minHeight: WTMLayout.ctaHeight)
            .background(Color.wtmDarkBlue, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.7, bounce: 0.3), value: rotations)
        .scaleEffect(isBreathing ? 1.04 : 1)
        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: isBreathing)
        .onAppear { isBreathing = true }
    }
}

// MARK: - Tabs

struct MainTabView: View {
    /// Not called `Tab` — that would shadow SwiftUI's `Tab` view inside this
    /// type, and the tab builders below need it.
    enum TabID: Hashable {
        case friends, groups, home, notifications, myself
    }

    @State private var selection: TabID = .home
    @Environment(DeepLinkRouter.self) private var deepLinks

    var body: some View {
        // All five use `Tab(_:systemImage:value:)`. A photo in the "myself" item
        // doesn't work: the bar extracts a plain image out of the tab's label
        // and draws it as a template, so the picture came through as a solid
        // black square no matter what rendering mode was asked for.
        TabView(selection: $selection) {
            Tab("friends", systemImage: "person.fill", value: TabID.friends) {
                FriendsTabView()
            }
            Tab("groups", systemImage: "person.2.fill", value: TabID.groups) {
                GroupsTabView()
            }
            Tab("home", systemImage: "house.fill", value: TabID.home) {
                HomeTabView()
            }
            Tab("requests", systemImage: "bubble.left.and.bubble.right.fill", value: TabID.notifications) {
                RequestsTabView()
            }
            Tab("myself", systemImage: "person.crop.square.fill", value: TabID.myself) {
                ProfileTabView()
            }
        }
        .onAppear { UIApplication.resetBadgeCount() }
        // A push's destination is a request, which lives in this tab. Select it
        // and let the tab do the pushing — it's the only place that knows
        // whether the request is still open.
        //
        // Both hooks are needed: a warm launch changes the target while this
        // view is on screen, and a cold launch from a notification has already
        // parked one before this view exists.
        .onChange(of: deepLinks.boredRequest) { _, target in
            if target != nil { selection = .notifications }
        }
        .task {
            if deepLinks.boredRequest != nil { selection = .notifications }
        }
        .notificationNudge()
    }
}

// MARK: - Notification nudge

/// Offers to turn notifications on when they're off.
///
/// Its own modifier rather than more links in `MainTabView.body`: that chain
/// already carries five tabs and three modifiers, and folding an alert with
/// branching actions into it pushed the type-checker past its budget — which
/// surfaces as a "unable to type-check this expression in reasonable time"
/// error and, because the checker then gives up on the file, a cascade of
/// bogus "cannot find X in scope" errors for everything else in it.
private struct NotificationNudge: ViewModifier {
    @State private var reason: PushManager.PromptReason?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .task { await offerIfNeeded() }
            .alert(reason?.title ?? "", isPresented: $isPresented) {
                actions
            } message: {
                Text(reason?.message ?? "")
            }
    }

    @ViewBuilder
    private var actions: some View {
        if let reason {
            Button(reason.actionTitle) { accept(reason) }
        }
        Button("don't ask again", role: .destructive) {
            PushManager.suppressPrompts()
        }
        Button("not now", role: .cancel) {
            PushManager.notePromptDeclined()
        }
    }

    private func accept(_ reason: PushManager.PromptReason) {
        switch reason {
        case .neverAsked:
            Task { await PushManager.requestAuthorization(uid: SecureStorage.uid) }
        case .blockedInSettings:
            PushManager.openSystemSettings()
        }
    }

    /// Someone who skipped the step during sign-up, or signed into an existing
    /// account on a fresh install, has never seen the system prompt — and the
    /// app has no other moment where it would notice. `PushManager` decides
    /// whether the ask is welcome: not within a few days of a "not now", and
    /// never after a "don't ask again".
    private func offerIfNeeded() async {
        // A beat, so the ask doesn't land on top of the launch transition.
        try? await Task.sleep(for: .seconds(2))
        guard let reason = await PushManager.promptReason() else { return }
        self.reason = reason
        isPresented = true
    }
}

private extension View {
    func notificationNudge() -> some View {
        modifier(NotificationNudge())
    }
}
