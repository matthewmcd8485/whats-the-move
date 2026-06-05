//
//  PushNotificationManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//
//  NOTE: As of the Tier 3 stabilization pass, this manager is not invoked
//  from anywhere in the codebase. AppDelegate handles MessagingDelegate
//  directly, and FCM token refresh happens inline in VerificationVC /
//  FinishingUpVC. Kept here as a real singleton in case it gets wired up
//  again — otherwise safe to delete.
//

import UIKit
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

final class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    static let shared = PushNotificationManager()
    
    private override init() {
        super.init()
    }
    
    public func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in })
        Messaging.messaging().delegate = self
        
        UIApplication.shared.registerForRemoteNotifications()
        updateFirestorePushTokenIfNeeded()
    }
    
    public func updateFirestorePushTokenIfNeeded() {
        guard let uid = SecureStorage.uid, let token = Messaging.messaging().fcmToken else { return }
        DatabaseManager.shared.updateFCMToken(uid: uid, newToken: token)
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateFirestorePushTokenIfNeeded()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print(response)
    }
}
