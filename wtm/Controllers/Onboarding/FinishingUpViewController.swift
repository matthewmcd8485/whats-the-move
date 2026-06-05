//
//  InitialContactsImportViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging
import ContactsUI

class FinishingUpViewController: UIViewController, UNUserNotificationCenterDelegate, MessagingDelegate {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()

        UNUserNotificationCenter.current().delegate = self
    }
    
    @IBAction func addProfilePictureButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "pictureEditViewController") as PictureEditViewController
        
        // Picture Edit View Controller has a completion handler but we do not need it when simply creating an account
        vc.completion = { result in
            print(result)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func enableNotifications(_ sender: Any) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if let error = error {
                print(error)
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("Error fetching FCM registration token: \(error)")
                    } else if let token = token {
                        print("FCM registration token: \(token)")
                        SecureStorage.fcmToken = token
                    }
                }
            }
        }
    }

    // MARK: - Uploading User Info
    @IBAction func finishButton(_ sender: Any) {
        guard let name = UserDefaults.standard.string(forKey: "name"), let phoneNumber = SecureStorage.phoneNumber, let uid = SecureStorage.uid else {
            
            alertManager.showAlert(title: "error creating account", message: "some of your information was not found. please try again.")
            return
        }
        let fcmToken = SecureStorage.fcmToken ?? "Notifications not set up yet"
        
        let date = Date()
        let joinedTime = date.month + " " + date.year
        
        let status = "available"
        let substatus = "find me something to do"
        
        var profileImageURL = "No profile image yet"
        if UserDefaults.standard.string(forKey: "profileImageURL") != nil {
            profileImageURL = UserDefaults.standard.string(forKey: "profileImageURL")!
        } else {
            UserDefaults.standard.set("No profile image yet", forKey: "profileImageURL")
        }
        
        UserDefaults.standard.set(substatus, forKey: "substatus")
        UserDefaults.standard.set(status, forKey: "status")
        
        let newUser = User(name: name.lowercased(), phoneNumber: phoneNumber, uid: uid, fcmToken: fcmToken, status: "available", substatus: substatus, profileImageURL: profileImageURL, joinedTime: joinedTime)
        DatabaseManager.shared.createUser(newUser, completion: { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error creating user in Firestore: \(error)")
                return
            case .success:
                break
            }
            
            // Document successfully written
            
            DispatchQueue.main.async {
                Messaging.messaging().subscribe(toTopic: "All users") { error in
                    print("Failed to subscribe to notification topic: All users")
                    print(error!)
                }
                UserDefaults.standard.set(true, forKey: "loggedIn")
                UserDefaults.standard.set("available", forKey: "status")
                UserDefaults.standard.set(joinedTime, forKey: "joinedTime")
                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let mainScreen = storyboard.instantiateViewController(identifier: "tabBarController") as! TabBarController
                self?.navigationController?.pushViewController(mainScreen, animated: true)
            }
            
        })
    }
}
