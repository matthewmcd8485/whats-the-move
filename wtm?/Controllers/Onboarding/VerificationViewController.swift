//
//  VerificationViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase
import UserNotifications

class VerificationViewController: UIViewController, UITextFieldDelegate {

    let alertManager = AlertManager.shared
    let db = Firestore.firestore()
    let storage = Storage.storage()
    let databaseManager = DatabaseManager.shared
    
    var uid = ""
    
    @IBOutlet weak var verificationCodeField: UITextField!
    @IBOutlet weak var nextLabel: UILabel!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var nextButtonView: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        verificationCodeField.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    private func createSpinnerView() {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: nextButtonView.frame.midY, width: 20, height: 20)
        
        activityIndicator.startAnimating()
        
        nextButtonView.isHidden = true
        nextLabel.isHidden = true
        arrow.isHidden = true
        
        view.addSubview(activityIndicator)
        //spinner.hudView.frame = CGRect(x: view.center.x, y: view.center.y - 120, width: 50, height: 50)
        //spinner.show(in: view)
        
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
                    if let error = error {
                        print("Error fetching FCM registration token: \(error)")
                    } else if let token = token {
                        print("FCM registration token: \(token)")
                        UserDefaults.standard.set(token, forKey: "fcmToken")
                        
                        
                        self?.db.collection("users").document(self!.uid).setData([
                            "FCM Token" : token
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
                    UserDefaults.standard.set(strongSelf.uid, forKey: "uid")
                    
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(identifier: "nameViewController") as! NameViewController
                    strongSelf.navigationController?.pushViewController(vc, animated: true)
                } else {
                    // This is a returning user!
                    // Download their information, cache it, and send them to the home screen
                    strongSelf.db.collection("users").whereField("User Identifier", isEqualTo: strongSelf.uid).getDocuments() { querySnapshot, error in
                        guard error == nil else {
                            print("Error downloading user information from Firestore: \(error!)")
                            return
                        }
                        UserDefaults.standard.set(strongSelf.uid, forKey: "uid")
                        
                        if querySnapshot?.documents.count == 0 {
                            
                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                            let vc = storyboard.instantiateViewController(identifier: "nameViewController") as! NameViewController
                            strongSelf.navigationController?.pushViewController(vc, animated: true)
                        } else {
                            for document in querySnapshot!.documents {
                                let name = document.get("Name") as! String
                                let status = document.get("Status") as! String
                                let substatus = document.get("Substatus") as! String
                                let profileImageURL = document.get("Profile Image URL") as! String
                                let fcmToken = document.get("FCM Token") as! String
                                let joined = document.get("Joined") as! String
                                
                                UserDefaults.standard.set(name, forKey: "name")
                                UserDefaults.standard.set(status, forKey: "status")
                                UserDefaults.standard.set(substatus, forKey: "substatus")
                                UserDefaults.standard.set(profileImageURL, forKey: "profileImageURL")
                                UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
                                UserDefaults.standard.set(joined, forKey: "joinedTime")
                                UserDefaults.standard.set(true, forKey: "loggedIn")
                                
                                // Download profile image
                                if profileImageURL != "No profile picture yet" {
                                    let storageRef = strongSelf.storage.reference(withPath: "profile images/\(strongSelf.uid) - profile image.png")
                                    storageRef.getData(maxSize: 2 * 2048 * 2048) { data, error in
                                        if let error = error {
                                            print(error)
                                        } else {
                                            // Data for profile image is returned
                                            print("data = \(data!)")
                                            let imageToSave = UIImage(data: data!)
                                            ImageStoreManager.shared.store(image: imageToSave!, forKey: "profileImage", withStorageType: .fileSystem)
                                        }
                                    }
                                }
                                // Update blocked users list
                                strongSelf.databaseManager.updateBlockedUsersList(uid: strongSelf.uid, completion: { success in
                                    print("blocked users list updated with result: \(success)")
                                })
                                
                                // Download friends list
                                self?.updateFriendsList()
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
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        var uids = [String]()
        
        databaseManager.downloadAllFriends(uid: uid, completion: { [weak self] result in
            switch result {
            case .success(let users):
                for x in users.count {
                    uids.append(users[x].uid)
                }
                UserDefaults.standard.set(uids, forKey: "friendsUID")
                self?.finishUp()
            case .failure(let error):
                print("\n *VERIFICATION VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
}
