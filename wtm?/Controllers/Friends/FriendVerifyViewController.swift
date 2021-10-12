//
//  FriendVerifyViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import Contacts
import Firebase
import SDWebImage
import PMAlertController

class FriendVerifyViewController: UIViewController {
    
    public var phoneNumber: String = ""
    public var comingFromGroup: Bool = false
    var friendToAdd: User = User(name: "", phoneNumber: "", uid: "", fcmToken: "", status: "", substatus: "", profileImageURL: "", joinedTime: "")
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let reportingManager = ReportingManager.shared
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var phoneNumberLabel: UILabel!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var addFriendLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var substatusLabel: UILabel!
    @IBOutlet weak var statusSymbol: UIImageView!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Override Functions
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        addFriendButton.layer.cornerRadius = 10
        statusView.layer.cornerRadius = 10
        
        profileImage.layer.cornerRadius = profileImage.frame.width / 2

        hideResultElements()
        createSpinnerView()
        search()
    }
    
    private func configureStatusView() {
        guard friendToAdd.name != "" else {
            return
        }
        if friendToAdd.status == "available" {
            statusView.backgroundColor = UIColor(named: "lightGreenOnLight")
            statusSymbol.image = UIImage(systemName: "checkmark.seal")
            statusSymbol.tintColor = UIColor(named: "darkGreenOnLight")
            statusLabel.text = friendToAdd.status
            substatusLabel.text  = friendToAdd.substatus
        } else if friendToAdd.status == "busy" {
            statusView.backgroundColor = UIColor(named: "lightYellowOnLight")
            statusSymbol.image = UIImage(systemName: "exclamationmark.bubble")
            statusSymbol.tintColor = UIColor(named: "darkYellowOnLight")
            statusLabel.text = friendToAdd.status
            substatusLabel.text  = friendToAdd.substatus
        } else if friendToAdd.status == "do not disturb" {
            statusView.backgroundColor = UIColor(named: "lightRedOnLight")
            statusSymbol.image = UIImage(systemName: "nosign")
            statusSymbol.tintColor = UIColor(named: "darkRedOnLight")
            statusLabel.text = "stfu!"
            substatusLabel.text  = friendToAdd.substatus
        }
        
    }
    
    private func hideResultElements() {
        profileImage.alpha = 0
        nameLabel.alpha = 0
        phoneNumberLabel.alpha = 0
        addFriendLabel.alpha = 0
        addFriendButton.alpha = 0
        loadingLabel.alpha = 1
        activityIndicator.alpha = 1
        statusLabel.alpha = 0
        statusSymbol.alpha = 0
        substatusLabel.alpha = 0
        statusView.alpha = 0
    }
    
    private func createSpinnerView() {
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: loadingLabel.frame.maxY + 50, width: 20, height: 20)
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(profileImage)
        //spinner.hudView.frame = CGRect(x: view.center.x, y: view.center.y - 120, width: 50, height: 50)
        //spinner.show(in: view)
        
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func cancelOperation() {
        let alert = PMAlertController(title: "user not found", description: "there were no matches given the phone number provided.", image: nil, style: .alert)
        let action = PMAlertAction(title: "okay", style: .default, action: {
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Search
    private func search() {
        databaseManager.downloadUser(where: "Phone Number", isEqualTo: phoneNumber, completion: { [weak self] result in
            switch result {
            case .success(let user):
                self?.friendToAdd = user
                
                // Check if someone blocked someone
                if self!.reportingManager.userBlockedYou(theirUID: self!.friendToAdd.uid) || self!.reportingManager.userIsBlocked(theirUID: self!.friendToAdd.uid) {
                    let alert = PMAlertController(title: "user is blocked", description: "either they blocked you or you blocked them.\n we don't know, though.\n it's not really our business.\n\nsorry for any drama this may cause...", image: nil, style: .alert)
                    alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
                    let action = PMAlertAction(title: "rude, but okay", style: .default, action: {
                        self?.navigationController?.popViewController(animated: true)
                    })
                    alert.addAction(action)
                    self?.present(alert, animated: true, completion: nil)
                } else {
                    self?.updateUI()
                    self?.configureStatusView()
                }
            case .failure(let error):
                self?.cancelOperation()
                print(error)
            }
        })
    }
    
    private func updateUI() {
        if friendToAdd.name == "" {
            cancelOperation()
        } else {
            nameLabel.text = friendToAdd.name
            phoneNumberLabel.text = friendToAdd.phoneNumber
            
            let storageRef = Storage.storage().reference().child("profile images").child("\(friendToAdd.uid) - profile image.png")
            storageRef.downloadURL(completion: { [weak self] (url, error) in
                if error != nil {
                    self?.alertManager.showAlert(title: "Error downloading profile image", message: "There was a problem downloading your profile image. \n \n Error: \(error!)")
                }
                DispatchQueue.main.async {
                    self?.profileImage.sd_setImage(with: url, completed: nil)
                    
                    UIView.animate(withDuration: 0.5) {
                        self?.profileImage.alpha = 1
                        self?.nameLabel.alpha = 1
                        self?.phoneNumberLabel.alpha = 1
                        self?.addFriendLabel.alpha = 1
                        self?.addFriendButton.alpha = 1
                        self?.loadingLabel.alpha = 0
                        self?.activityIndicator.alpha = 0
                        self?.statusLabel.alpha = 1
                        self?.statusSymbol.alpha = 1
                        self?.substatusLabel.alpha = 1
                        self?.statusView.alpha = 1
                    }
                }
            })
        }
    }
    
    // MARK: - Add Friend
    @IBAction func addFriend(_ sender: Any) {
        guard let uid = UserDefaults.standard.string(forKey: "uid"), let name = UserDefaults.standard.string(forKey: "name"), let profileImageURL = UserDefaults.standard.string(forKey: "profileImageURL"), friendToAdd.uid != "" else {
            alertManager.showAlert(title: "error adding friend", message: "dont worry. \n we don't know what happened either.")
            return
        }

        if checkIfAlreadyFriends() {
            let alert = PMAlertController(title: "already friends", description: "you can't send a friend request to someone you're already friends with. \n \n maybe if you used the app how it was intended then you wouldn't be stuck here doing stupid stuff like trying to create duplicate friends.", image: nil, style: .alert)
            alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
            alert.alertTitle.textColor = UIColor(named: "lightBrown")!
            alert.addAction(PMAlertAction(title: "ok, sorry", style: .default, action: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }))
            present(alert, animated: true)
        } else {
            db.collection("users").document(friendToAdd.uid).collection("friend requests").document(uid).setData([
                "Name" : name,
                "User Identifier" : uid,
                "Profile Image URL" : profileImageURL
            ], merge: true, completion: { [weak self] error in
                guard error == nil, let strongSelf = self else {
                    return
                }
                
                let sender = PushNotificationSender()
                let profileImageURL = UserDefaults.standard.string(forKey: "profileImageURL") ?? ""
                sender.sendPushNotification(to: strongSelf.friendToAdd.fcmToken, title: "new friend request", subtitle: "", body: "\(name) wants to be your friend.", urlToImage: profileImageURL)
                
                print("friend request sent!")
                
                if strongSelf.comingFromGroup {
                    strongSelf.navigationController?.popViewController(animated: true)
                } else {
                    strongSelf.navigationController?.popToRootViewController(animated: true)
                }
            })
        }
    }
    
    private func checkIfAlreadyFriends() -> Bool {
        if let friendsUID = UserDefaults.standard.stringArray(forKey: "friendsUID") {
            for x in friendsUID.count {
                if friendToAdd.uid == friendsUID[x] {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Reporting
    @IBAction func reportButton(_ sender: Any) {
        let alert = PMAlertController(title: "user options", description: "you can report or block a user here.", image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = UIColor(named: "lightBrown")!
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
        alert.addAction(PMAlertAction(title: "report user", style: .default, action: { [weak self] in
            self?.reportUser()
        }))
        alert.addAction(PMAlertAction(title: "block user", style: .default, action: { [weak self] in
            self?.blockUser()
        }))
        present(alert, animated: true)
    }
    
    private func blockUser() {
        let alert = PMAlertController(title: "block user", description: "are you sure? \n \nany groups you are in with this person will NOT be deleted.\n\nthis action cannot be undone.", image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = .systemRed
        alert.addAction(PMAlertAction(title: "oops, cancel", style: .cancel))
        alert.addAction(PMAlertAction(title: "block user", style: .default, action: { [weak self] in
            self?.databaseManager.blockUser(uidToBlock: self!.friendToAdd.uid, completion: { success in
                if success {
                    let alert = PMAlertController(title: "user blocked", description: "you have successfully blocked this person.\n\nsorry they were mean to you or whatever.", image: nil, style: .alert)
                    alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
                    alert.addAction(PMAlertAction(title: "yeah, me too", style: .default, action: {
                        self?.navigationController?.popViewController(animated: true)
                    }))
                    self?.present(alert, animated: true, completion: nil)
                } else {
                    self?.alertManager.showAlert(title: "error blocking user", message: "there was an error when blocking the user. please try again.")
                }
            })
        }))
        present(alert, animated: true)
    }
    
    private func reportUser() {
        let alert = PMAlertController(title: "report user", description: "are you sure? \n this action cannot be undone.", image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = .systemRed
        alert.addAction(PMAlertAction(title: "oops, cancel", style: .cancel))
        alert.addAction(PMAlertAction(title: "report user", style: .default, action: { [weak self] in
            self?.reportingManager.reportUser(uid: self!.friendToAdd.uid, name: self!.friendToAdd.name, date: Date().toString(dateFormat: "yyyy-MM-dd 'at' HH:mm:ss"), completion: { success in
                if success {
                    print("user reported!")
                    self?.navigationController?.popViewController(animated: true)
                } else {
                    self?.alertManager.showAlert(title: "error reporting user", message: "something went wrong when reporting the user. please try again.")
                }
            })
        }))
        present(alert, animated: true)
    }
}

extension FriendVerifyViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
