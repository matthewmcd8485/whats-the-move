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

// AppDelegate is implicitly @MainActor via UIApplicationDelegate, while
// MessagingDelegate and UNUserNotificationCenterDelegate are nonisolated Obj-C
// protocols. `@preconcurrency` on the conformances tells the compiler these
// callbacks do arrive on the main thread.
@main
class AppDelegate: UIResponder, UIApplicationDelegate, @preconcurrency MessagingDelegate {

    var window: UIWindow?
    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        
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
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.hexString // Defined in the Data extension file
        print("\n\nAPNS Device Token: \(token)\n\n")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error)")
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
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        //print("Firebase registration token: \(String(describing: fcmToken))")
        
        let dataDict:[String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
    // Identifiers for the actions on the "someone is bored" push. Each action
    // needs its own identifier — they previously all reused the reserved
    // `UNNotificationDefaultActionIdentifier`, which made them indistinguishable
    // in `didReceive` and conflated them with a plain tap on the notification.
    enum BoredPushAction {
        static let category = "CustomPush"
        static let available = "wtm.boredResponse.available"
        static let busy = "wtm.boredResponse.busy"
        static let doNotDisturb = "wtm.boredResponse.doNotDisturb"
    }

    private func registerNotificationCategories() {
        let availableAction = UNNotificationAction(identifier: BoredPushAction.available, title: "count me in!", options: .foreground)
        let busyAction = UNNotificationAction(identifier: BoredPushAction.busy, title: "might be busy today", options: .foreground)
        let dndAction = UNNotificationAction(identifier: BoredPushAction.doNotDisturb, title: "stop talking to me", options: .foreground)
        let someoneIsBoredCategory = UNNotificationCategory(
            identifier: BoredPushAction.category,
            actions: [availableAction, busyAction, dndAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([someoneIsBoredCategory])
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    
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
        
        // ...
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print full message.
        print(userInfo)
        
        defer {
            completionHandler()
        }

        // Identify the action by matching its identifier. Now that the three
        // response buttons carry distinct identifiers they can be told apart
        // here; a plain tap on the notification still arrives as the default
        // action identifier.
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            Log.push.info("Notification body tapped")
            // TODO: deep-link into the open request.
        case BoredPushAction.available:
            Log.push.info("Bored push answered: available")
            // TODO: write the chosen response back to Firestore.
        case BoredPushAction.busy:
            Log.push.info("Bored push answered: busy")
            // TODO: write the chosen response back to Firestore.
        case BoredPushAction.doNotDisturb:
            Log.push.info("Bored push answered: do not disturb")
            // TODO: write the chosen response back to Firestore.
        default:
            break
        }
    }
}

