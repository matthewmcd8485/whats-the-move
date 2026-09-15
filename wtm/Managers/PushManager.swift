//
//  PushManager.swift
//  wtm?
//
//  Getting — and keeping — a working push registration.
//
//  This was previously split between two places with a gap at each end:
//
//  * The system permission prompt only ever appeared on the last step of
//    *sign-up*. An existing account signing in — which is what a delete and
//    reinstall looks like — went straight to the home screen and was never
//    asked, and anyone who skipped the step was never asked a second time.
//
//  * The FCM token was only written to Firestore from `SessionModel.start()`,
//    which signing in doesn't go through. So a fresh sign-in left whatever
//    token the document already held — often another install's — until the app
//    was next launched cold.
//
//  Both ends are now the same call: `refreshRegistration(uid:)` on every
//  sign-in, every launch, and every time Firebase rotates the token.
//

import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

@MainActor
enum PushManager {

    /// Why the in-app nudge is being offered, which decides what it can do
    /// about it.
    enum PromptReason {
        /// The system prompt has never been shown, so it still can be.
        case neverAsked
        /// Already refused at the system level. iOS won't show the prompt a
        /// second time, so the only route back is Settings.
        case blockedInSettings

        var title: String {
            switch self {
            case .neverAsked: "enable notifications?"
            case .blockedInSettings: "notifications are off"
            }
        }

        var message: String {
            switch self {
            case .neverAsked:
                "notifications are off, so you'll never find out when your friends are bored.\n\nand what's the point of that?"
            case .blockedInSettings:
                "notifications are turned off for wtm?, so your friends can't reach you when they're bored.\n\nyou can switch them back on in iOS settings."
            }
        }

        var actionTitle: String {
            switch self {
            case .neverAsked: "yes, annoy me"
            case .blockedInSettings: "open settings"
            }
        }
    }

    private enum Key {
        /// Set when someone chooses "don't ask again". Cleared with everything
        /// else on sign-out, so a different account starts fresh.
        static let promptSuppressed = "notificationPromptSuppressed"
        /// When the nudge was last put on screen, so "not now" isn't ignored
        /// the next time the app opens.
        static let promptLastShown = "notificationPromptLastShown"
    }

    /// How long "not now" is honoured for.
    private static let promptCooldown: TimeInterval = 60 * 60 * 24 * 3

    // MARK: - Status

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Registration

    /// Brings `uid`'s document in line with this device.
    ///
    /// An FCM token belongs to the install, not the account, so switching
    /// accounts on one device has to move it onto the new document — otherwise
    /// the account that's signed in has no token at all and the pushes keep
    /// going to the one that isn't.
    static func refreshRegistration(uid: String) async {
        guard await authorizationStatus().allowsNotifications else {
            // Clear the field rather than leaving a token behind that can't
            // deliver. The fan-out skips empty strings; it does *not* skip the
            // "Notifications not set up yet" placeholder sign-up used to write,
            // so that would be handed to FCM as if it were a real token.
            Log.push.info("notifications aren't authorized; clearing the stored token")
            DatabaseManager.shared.updateFCMToken(uid: uid, newToken: "")
            SecureStorage.fcmToken = nil
            return
        }

        // Every process has to ask again — the APNs device token isn't
        // persisted — but this call only *starts* the round-trip to Apple. The
        // token lands on the app delegate some time later.
        UIApplication.shared.registerForRemoteNotifications()

        guard Messaging.messaging().apnsToken != nil else {
            // Firebase won't mint an FCM token before it has the APNs one, and
            // asking anyway just logs "Declining request for FCM Token since no
            // APNS Token specified" and returns nothing. `AppDelegate`'s
            // `didRegisterForRemoteNotificationsWithDeviceToken` picks this back
            // up the moment the token arrives.
            Log.push.info("waiting on the APNs device token before resolving an FCM token")
            return
        }

        await writeToken(uid: uid)
    }

    /// Resolves this install's FCM token and writes it onto `uid`'s document.
    ///
    /// Only safe once `Messaging.apnsToken` is set — call `refreshRegistration`
    /// rather than this, unless you're being told the APNs token just arrived.
    ///
    /// Written unconditionally. The two guards this replaces both dropped
    /// writes that were needed: bailing when nothing was cached meant a fresh
    /// install never registered at all, and bailing when the token was
    /// unchanged meant signing in as a different account on the same device
    /// left the new account with no token while the *previous* account's
    /// document still pointed here. That's how a request ended up notifying its
    /// own sender on a second device.
    static func writeToken(uid: String) async {
        do {
            let token = try await Messaging.messaging().token()
            DatabaseManager.shared.updateFCMToken(uid: uid, newToken: token)
            SecureStorage.fcmToken = token
        } catch {
            Log.push.error("couldn't resolve an FCM token: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Discards this install's FCM token so whoever signs in next gets a new
    /// one.
    ///
    /// Clearing the field on the account being left is the main defence, but
    /// that write can fail offline — and a token discarded here can't deliver
    /// to the abandoned account even if it does.
    static func discardToken() {
        SecureStorage.fcmToken = nil
        Task {
            do {
                try await Messaging.messaging().deleteToken()
            } catch {
                Log.push.error("couldn't delete the FCM token on sign-out: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Permission

    /// Shows the system permission prompt, then brings the registration in line
    /// with whatever was chosen.
    ///
    /// Pass `nil` for `uid` during sign-up, where there's no user document to
    /// write to yet; `createAccount` calls `refreshRegistration` once there is.
    ///
    /// Safe to call when permission has already been decided: iOS only ever
    /// puts this on screen once per install, and afterwards
    /// `requestAuthorization` returns the stored answer without showing
    /// anything. That's also why a denied account has to be sent to Settings
    /// rather than asked again.
    @discardableResult
    static func requestAuthorization(uid: String?) async -> Bool {
        notePromptShown()

        var granted = false
        do {
            granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.push.error("notification permission request failed: \(error.localizedDescription, privacy: .public)")
        }

        if granted {
            // Start the APNs round-trip now, so the device token is on its way
            // while the rest of sign-in finishes.
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            Log.push.info("notification permission declined")
        }

        if let uid {
            // Runs whether or not it was granted: a refusal has to clear the
            // token this account was holding, not merely skip writing one.
            await refreshRegistration(uid: uid)
        }
        return granted
    }

    /// Why the nudge should be shown now, or `nil` to leave it alone.
    ///
    /// Notifications being off is checked every time rather than trusted to a
    /// flag: someone can turn them off in Settings long after saying yes here.
    static func promptReason() async -> PromptReason? {
        guard !UserDefaults.standard.bool(forKey: Key.promptSuppressed) else { return nil }

        let status = await authorizationStatus()
        guard !status.allowsNotifications else { return nil }

        if let lastShown = UserDefaults.standard.object(forKey: Key.promptLastShown) as? Date,
           Date().timeIntervalSince(lastShown) < promptCooldown {
            return nil
        }

        return status == .denied ? .blockedInSettings : .neverAsked
    }

    /// "not now" — ask again, but not for a few days.
    static func notePromptDeclined() {
        notePromptShown()
    }

    /// "don't ask again" — stop offering for good.
    static func suppressPrompts() {
        Log.push.info("notification prompts suppressed at the person's request")
        UserDefaults.standard.set(true, forKey: Key.promptSuppressed)
    }

    /// Opens this app's notification settings directly, rather than dropping
    /// someone at the top of Settings to find it themselves.
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func notePromptShown() {
        UserDefaults.standard.set(Date(), forKey: Key.promptLastShown)
    }
}

private extension UNAuthorizationStatus {
    /// Whether the system will actually deliver anything we send.
    var allowsNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .denied, .notDetermined: false
        @unknown default: false
        }
    }
}
