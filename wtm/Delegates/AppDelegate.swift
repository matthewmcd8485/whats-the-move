//
//  AppDelegate.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// Attached to the SwiftUI App with `UIApplicationDelegateAdaptor` rather than
// being the entry point itself — Firebase Messaging and the notification
// categories still need a UIApplicationDelegate to hang off.
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {

    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        // Without this, nothing below ever runs: the response buttons were
        // registered but `didReceive` was never called, so tapping one only
        // opened the app and dropped the answer on the floor.
        UNUserNotificationCenter.current().delegate = self

        registerNotificationCategories()

        if UserDefaults.standard.string(forKey: "profileImageURL") == nil {
            UserDefaults.standard.set("No profile image yet", forKey: "profileImageURL")
        }

        syncVersionPreference()
        
        return true
    }

    private func syncVersionPreference() {
        let value = "\(UIApplication.appVersion()) (build \(UIApplication.appBuild()))"
        UserDefaults.standard.set(value, forKey: "version_preference")
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Notifications
    // The APNs device token arrives here, asynchronously, some time after
    // `registerForRemoteNotifications()` was called. Firebase's app-delegate
    // proxy sets `Messaging.apnsToken` from it — and until that happens it
    // declines to mint an FCM token at all, so this is the earliest moment one
    // can be resolved. Whoever asked before now got nothing.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.push.info("APNs device token registered: \(deviceToken.hexString, privacy: .private)")

        guard let uid = SecureStorage.uid,
              UserDefaults.standard.bool(forKey: "loggedIn") else { return }
        Task { await PushManager.writeToken(uid: uid) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on a simulator without a paired push environment; on device
        // it means no notification will ever arrive.
        Log.push.error("couldn't register with APNs: \(error.localizedDescription, privacy: .public)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        UIApplication.incrementBadgeCount()
        
        // Print full message.
        print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        UIApplication.incrementBadgeCount()
        
        // Print full message.
        print(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    // Fires at every app start and whenever Firebase mints a new token — after
    // a restore, an app update, or the `deleteToken()` on sign-out. The user
    // document has to follow it rather than only being written at launch, or a
    // rotation leaves the account unreachable until the next cold start.
    //
    // This used to post the token to a NotificationCenter name that nothing
    // observed, so a rotation was silently dropped.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let uid = SecureStorage.uid,
              UserDefaults.standard.bool(forKey: "loggedIn") else { return }

        // Re-resolving rather than trusting the token handed in here, so
        // there's one path that decides what the document should say — and it
        // clears the field instead when notifications aren't authorized.
        Task { await PushManager.refreshRegistration(uid: uid) }
    }
    
    // Identifiers for the actions on the "someone is bored" push. Each action
    // needs its own identifier — they previously all reused the reserved
    // `UNNotificationDefaultActionIdentifier`, which made them indistinguishable
    // in `didReceive` and conflated them with a plain tap on the notification.
    enum BoredPushAction {
        static let category = "CustomPush"
        static let available = "wtm.boredResponse.available"
        static let busy = "wtm.boredResponse.busy"
        static let notAvailable = "wtm.boredResponse.notAvailable"
        static let reply = "wtm.boredResponse.reply"

        /// The category each one-tap button answers with.
        static func category(forActionIdentifier identifier: String) -> BoredResponseCategory? {
            switch identifier {
            case available: .available
            case busy: .busy
            case notAvailable: .notAvailable
            default: nil
            }
        }
    }

    private func registerNotificationCategories() {
        let availableAction = UNNotificationAction(identifier: BoredPushAction.available, title: "count me in!", options: .foreground)
        let busyAction = UNNotificationAction(identifier: BoredPushAction.busy, title: "might be busy today", options: .foreground)
        let notAvailableAction = UNNotificationAction(identifier: BoredPushAction.notAvailable, title: "stop talking to me", options: .foreground)
        // The one action that doesn't open the app. Typing a message is the
        // point of a quick reply, so it's answered in place; the three buttons
        // above open the request so you can see where your answer landed.
        let replyAction = UNTextInputNotificationAction(
            identifier: BoredPushAction.reply,
            title: "custom",
            options: [],
            textInputButtonTitle: "send",
            textInputPlaceholder: "say something"
        )
        let someoneIsBoredCategory = UNNotificationCategory(
            identifier: BoredPushAction.category,
            actions: [availableAction, busyAction, notAvailableAction, replyAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([someoneIsBoredCategory])
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // ...
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([[.banner, .sound, .badge]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let target = Self.boredRequestIdentifiers(from: userInfo)

        // Identify the action by matching its identifier. A plain tap on the
        // notification arrives as the default action identifier.
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // A tap opens the request without answering it.
            if let target {
                DeepLinkRouter.shared.open(groupID: target.groupID, requestID: target.requestID)
            }
            completionHandler()

        case BoredPushAction.reply:
            let typed = (response as? UNTextInputNotificationResponse)?
                .userText
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let target, !typed.isEmpty else {
                completionHandler()
                return
            }
            // A typed message says nothing about whether you're free, so it
            // goes in uncategorized rather than being assumed to mean "yes".
            // The app may have been woken purely to run this, so the write has
            // to finish before we report back or the system can suspend us
            // mid-flight.
            Log.push.info("Bored push answered with a custom message")
            let choice = BoredResponseChoice(
                status: BoredResponseCategory.uncategorized.rawValue,
                substatus: typed
            )
            Task {
                await Self.submit(choice, to: target)
                completionHandler()
            }

        default:
            guard let category = BoredPushAction.category(forActionIdentifier: response.actionIdentifier),
                  let target else {
                completionHandler()
                return
            }
            Log.push.info("Bored push answered: \(category.rawValue, privacy: .public)")
            let choice = BoredResponseChoice(
                status: category.rawValue,
                substatus: category.notificationActionMessage
            )
            // Deep-link immediately and carry the choice along rather than
            // waiting on Firestore: offline, `setData` doesn't acknowledge
            // until the write syncs, and the person is already looking at the
            // request by then.
            DeepLinkRouter.shared.open(
                groupID: target.groupID,
                requestID: target.requestID,
                chosenResponse: choice
            )
            Task {
                await Self.submit(choice, to: target)
                completionHandler()
            }
        }
    }

    /// The request a push belongs to. The Cloud Function puts both identifiers
    /// in the FCM data dictionary, which arrives at the top level of `userInfo`.
    private static func boredRequestIdentifiers(
        from userInfo: [AnyHashable: Any]
    ) -> (groupID: String, requestID: String)? {
        guard let groupID = userInfo["groupId"] as? String, !groupID.isEmpty,
              let requestID = userInfo["requestId"] as? String, !requestID.isEmpty else {
            Log.push.info("push carried no request identifiers, so there's nothing to open")
            return nil
        }
        return (groupID, requestID)
    }

    private static func submit(
        _ choice: BoredResponseChoice,
        to target: (groupID: String, requestID: String)
    ) async {
        guard let uid = SecureStorage.uid else { return }
        do {
            try await DatabaseManager.shared.updateBoredRequestResponse(
                groupID: target.groupID,
                requestID: target.requestID,
                uid: uid,
                status: choice.status,
                substatus: choice.substatus
            )
        } catch {
            Log.push.error("couldn't save the response from the notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}

