//
//  VerificationViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
import UserNotifications

class VerificationViewController: UIViewController, UITextFieldDelegate {

    let alertManager = AlertManager.shared
    let db = Firestore.firestore()
    let storage = Storage.storage()
    let databaseManager = DatabaseManager.shared
 
    let activityIndicator = UIActivityIndicatorView(style: .large)
    var uid = ""
    var continuing = false
    
    @IBOutlet weak var verificationCodeField: UITextField!
    @IBOutlet weak var nextLabel: UILabel!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var nextButtonView: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: nextButtonView.frame.midY, width: 20, height: 20)
        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true

        verificationCodeField.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    private func createSpinnerView() {
        activityIndicator.startAnimating()
        
        activityIndicator.isHidden = false
        nextButtonView.isHidden = true
        nextLabel.isHidden = true
        arrow.isHidden = true
    }
    
    private func dismissSpinnerView() {
        activityIndicator.stopAnimating()
        
        activityIndicator.isHidden = true
        nextButtonView.isHidden = false
        nextLabel.isHidden = false
        arrow.isHidden = false
    }
    
    // MARK: - Text Field Delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func enableNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if let error = error {
                print(error)
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Messaging.messaging().token { [weak self] token, error in
                    guard let self = self else { return }
                    if let error = error {
                        print("Error fetching FCM registration token: \(error)")
                    } else if let token = token {
                        print("FCM registration token: \(token)")
                        SecureStorage.fcmToken = token
                        
                        
                        self.db.collection(FirestoreKeys.Collection.users).document(self.uid).setData([
                            FirestoreKeys.User.fcmToken : token
                        ], merge: true, completion: { error in
                            guard error == nil else {
                                print("Error updating FCM Token in Firestore: \(error!)")
                                return
                            }
                        })
                    }
                }
            }
        }
    }
    
    // MARK: - Signing In
    @IBAction func finishButton(_ sender: Any) {
        guard let verificationCode = verificationCodeField.text else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if !strongSelf.continuing {
                strongSelf.alertManager.showAlert(title: "loading error", message: "something went wrong here. check your internet connection and try again.")
                strongSelf.dismissSpinnerView()
                return
            }
        }
        
        if verificationCode == "" {
            alertManager.showAlert(title: "no code entered", message: "please enter the verification code that was sent to your phone.")
        } else {
            createSpinnerView()
            guard let verificationID = UserDefaults.standard.string(forKey: "verificationID") else {
                print("no verification ID found in user defaults.")
                return
            }
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
            
            Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
                if let error = error {
                    let authError = error as NSError
                    print(authError.description)
                    return
                }
                
                guard let strongSelf = self else {
                    return
                }
                
                // User has signed in successfully and currentUser object is valid
                let currentUserInstance = Auth.auth().currentUser
                strongSelf.uid = currentUserInstance!.uid
                
                
                if authResult!.additionalUserInfo!.isNewUser {
                    // This is a new user!
                    // Send them to complete the onboarding flow
                    SecureStorage.uid = strongSelf.uid
                    
                    self?.continuing = true
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(identifier: "nameViewController") as! NameViewController
                    strongSelf.navigationController?.pushViewController(vc, animated: true)
                } else {
                    // This is a returning user!
                    // Download their information, cache it, and send them to the home screen
                    strongSelf.db.collection(FirestoreKeys.Collection.users).whereField(FirestoreKeys.User.userIdentifier, isEqualTo: strongSelf.uid).getDocuments() { querySnapshot, error in
                        guard error == nil else {
                            print("Error downloading user information from Firestore: \(error!)")
                            return
                        }
                        SecureStorage.uid = strongSelf.uid
                        self?.continuing = true
                        if querySnapshot?.documents.count == 0 {
                            
                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                            let vc = storyboard.instantiateViewController(identifier: "nameViewController") as! NameViewController
                            strongSelf.navigationController?.pushViewController(vc, animated: true)
                        } else {
                            guard let documents = querySnapshot?.documents else { return }
                            for document in documents {
                                guard let user = try? document.data(as: User.self) else { continue }
                                
                                UserDefaults.standard.set(user.name, forKey: "name")
                                UserDefaults.standard.set(user.status, forKey: "status")
                                UserDefaults.standard.set(user.substatus, forKey: "substatus")
                                UserDefaults.standard.set(user.profileImageURL, forKey: "profileImageURL")
                                SecureStorage.fcmToken = user.fcmToken
                                UserDefaults.standard.set(user.joinedTime, forKey: "joinedTime")
                                UserDefaults.standard.set(true, forKey: "loggedIn")
                                
                                // Download profile image
                                if user.profileImageURL != "No profile picture yet" {
                                    let storageRef = strongSelf.storage.reference(withPath: "profile images/\(strongSelf.uid) - profile image.png")
                                    storageRef.getData(maxSize: 2 * 2048 * 2048) { data, error in
                                        if let error = error {
                                            print(error)
                                        } else {
                                            // Data for profile image is returned
                                            print("data = \(data!)")
                                            let imageToSave = UIImage(data: data!)
                                            ImageStoreManager.shared.store(image: imageToSave!, forKey: "profileImage")
                                        }
                                    }
                                }
                                // Update blocked users list
                                strongSelf.databaseManager.updateBlockedUsersList(uid: strongSelf.uid, completion: { success in
                                    print("blocked users list updated with result: \(success)")
                                })
                                
                                // Download friends and groups list
                                self?.updateFriendsList()
                                self?.updateFriendGroups()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func finishUp() {
        
        enableNotifications()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "tabBarController") as! TabBarController
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func updateFriendsList() {
        guard let uid = SecureStorage.uid else {
            return
        }
        var uids = [String]()
        
        databaseManager.downloadAllFriends(uid: uid, completion: { [weak self] result in
            switch result {
            case .success(let users):
                for x in 0..<users.count {
                    uids.append(users[x].uid)
                }
                UserDefaults.standard.set(uids, forKey: "friendsUID")
                self?.finishUp()
            case .failure(let error):
                print("\n *VERIFICATION VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
    private func updateFriendGroups() {
        guard let uid = SecureStorage.uid else {
            return
        }
        var groupIDs = [String]()
        
        databaseManager.downloadAllGroups(uid: uid, completion: { result in
            switch result {
            case .success(let downloadedGroups):
                for x in 0..<downloadedGroups.count {
                    groupIDs.append(downloadedGroups[x].groupID)
                }
                UserDefaults.standard.set(groupIDs, forKey: "groupsUID")
            case .failure(let error):
                print("\n *GROUPS VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
}
