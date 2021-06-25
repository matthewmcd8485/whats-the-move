//
//  PushNotificationManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import UIKit
import Firebase
import UserNotifications

class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    let uid: String
    
    let firestore = Firestore.firestore()
    
    init(uid: String) {
        self.uid = uid
        super.init()
    }
    
    public func registerForPushNotifications() {
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in })
            // For iOS 10 data message (sent via FCM)
            Messaging.messaging().delegate = self
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        
        UIApplication.shared.registerForRemoteNotifications()
        updateFirestorePushTokenIfNeeded()
    }
    
    func updateFirestorePushTokenIfNeeded() {
        if let token = Messaging.messaging().fcmToken {
            firestore.collection("users").document(uid).setData([
                "FCM Token": token
            ], merge: true) { error in
                guard error == nil else {
                    print("Error updating cloud messaging token: \(error!)")
                    return
                }
            }
        }
    }
    
    //func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
    //    print(remoteMessage.appData) // or do whatever
    //}
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateFirestorePushTokenIfNeeded()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print(response)
    }
}
