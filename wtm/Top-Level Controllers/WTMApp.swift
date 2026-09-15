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
import FirebaseMessaging

@main
struct WTMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Drives which of the three top-level states is on screen.
    @State private var session = SessionModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
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

    /// Decides where to send the person on launch and warms the caches the
    /// signed-in screens expect. Replaces LoadingViewController.
    func start() async {
        // A missing uid means signed out even if the flag says otherwise; that
        // can happen when the Keychain migration couldn't read the legacy
        // UserDefaults value.
        guard UserDefaults.standard.bool(forKey: "loggedIn"),
              let uid = SecureStorage.uid else {
            phase = .onboarding
            return
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
            phase = .onboarding
            return
        }

        await refreshPushToken(uid: uid)
        phase = .signedIn
    }

    /// Clears credentials and returns to onboarding.
    func signOut() {
        // Detach this device from the account being left, or its document goes
        // on holding this device's token and keeps receiving that account's
        // pushes after someone else signs in here.
        if let uid = SecureStorage.uid {
            DatabaseManager.shared.updateFCMToken(uid: uid, newToken: "")
        }
        SecureStorage.fcmToken = nil
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

    private func refreshPushToken(uid: String) async {
        do {
            let token = try await Messaging.messaging().token()
            // Written on every launch, unconditionally.
            //
            // The two guards this replaces both dropped writes that were
            // needed. Bailing when nothing was cached meant a fresh install
            // never registered at all; bailing when the token was unchanged
            // meant signing in as a different account on the same device left
            // the new account with no token while the *previous* account's
            // document still pointed here. That's how a request ended up
            // notifying its own sender on a second device.
            DatabaseManager.shared.updateFCMToken(uid: uid, newToken: token)
            SecureStorage.fcmToken = token
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            Log.push.error("launch — FCM token: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Root

struct RootView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        switch session.phase {
        case .launching:
            LaunchView()
                .task { await session.start() }
        case .onboarding:
            OnboardingFlowView(onFinished: { session.phase = .signedIn })
        case .signedIn:
            MainTabView()
        }
    }
}

/// The "loading..." screen shown while launch work runs.
struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.wtmLightBlue.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("wtm?")
                    .font(.wtmHero)
                    .foregroundStyle(Color.wtmDarkBlue)
                ProgressView()
                    .tint(.white)
            }
        }
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
    }
}
