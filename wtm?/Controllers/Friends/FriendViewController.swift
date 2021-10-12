//
//  FriendViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import UIKit
import Firebase
import PMAlertController

class FriendViewController: UIViewController {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let reportingManager = ReportingManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    public var friendsUID = ""
    var friend: User = User(name: "", phoneNumber: "", uid: "", fcmToken: "", status: "", substatus: "", profileImageURL: "", joinedTime: "")
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var substatusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        statusView.layer.cornerRadius = 10
        profileImage.layer.cornerRadius = profileImage.frame.width / 2
        
        createSpinnerView()
        hideResultElements()
        loadUser()
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UI Updates
    private func configureStatusView() {
        guard friend.name != "" else {
            return
        }
        if friend.status == "available" {
            statusView.backgroundColor = UIColor(named: "lightGreenOnLight")
            statusImage.image = UIImage(systemName: "checkmark.seal")
            statusImage.tintColor = UIColor(named: "darkGreenOnLight")
            statusLabel.text = friend.status
            substatusLabel.text  = friend.substatus
        } else if friend.status == "busy" {
            statusView.backgroundColor = UIColor(named: "lightYellowOnLight")
            statusImage.image = UIImage(systemName: "exclamationmark.bubble")
            statusImage.tintColor = UIColor(named: "darkYellowOnLight")
            statusLabel.text = friend.status
            substatusLabel.text  = friend.substatus
        } else if friend.status == "do not disturb" {
            statusView.backgroundColor = UIColor(named: "lightRedOnLight")
            statusImage.image = UIImage(systemName: "nosign")
            statusImage.tintColor = UIColor(named: "darkRedOnLight")
            statusLabel.text = "stfu!"
            substatusLabel.text  = friend.substatus
        }
        
    }
    
    private func hideResultElements() {
        profileImage.alpha = 0
        nameLabel.alpha = 0
        numberLabel.alpha = 0
        loadingLabel.alpha = 1
        activityIndicator.alpha = 1
        statusLabel.alpha = 0
        statusImage.alpha = 0
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
    
    // MARK: - Loading User
    private func cancelOperation() {
        let alert = PMAlertController(title: "friend not found", description: "we appear to be stuck inside a white void where your friends don't exist. \n \n or maybe it's just real life?", image: nil, style: .alert)
        let action = PMAlertAction(title: "rude, but okay", style: .default, action: {
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func loadUser() {
        databaseManager.downloadUser(where: "User Identifier", isEqualTo: friendsUID, completion: { [weak self] result in
            switch result {
            case .success(let user):
                self?.friend = user
                
                // Check if someone blocked someone
                if self!.reportingManager.userBlockedYou(theirUID: self!.friendsUID) || self!.reportingManager.userIsBlocked(theirUID: self!.friendsUID) {
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
        if friend.name == "" {
            cancelOperation()
        } else {
            nameLabel.text = friend.name
            numberLabel.text = friend.phoneNumber
            
            let storageRef = Storage.storage().reference().child("profile images").child("\(friend.uid) - profile image.png")
            storageRef.downloadURL(completion: { [weak self] (url, error) in
                if error != nil {
                    self?.alertManager.showAlert(title: "Error downloading profile image", message: "There was a problem downloading the profile image. \n \n Error: \(error!)")
                }
                DispatchQueue.main.async {
                    self?.profileImage.sd_setImage(with: url, completed: nil)
                    
                    UIView.animate(withDuration: 0.5) {
                        self?.profileImage.alpha = 1
                        self?.nameLabel.alpha = 1
                        self?.numberLabel.alpha = 1
                        self?.loadingLabel.alpha = 0
                        self?.activityIndicator.alpha = 0
                        self?.statusLabel.alpha = 1
                        self?.statusImage.alpha = 1
                        self?.substatusLabel.alpha = 1
                        self?.statusView.alpha = 1
                    }
                }
            })
        }
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
            self?.databaseManager.blockUser(uidToBlock: self!.friend.uid, completion: { success in
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
            self?.reportingManager.reportUser(uid: self!.friend.uid, name: self!.friend.name, date: Date().toString(dateFormat: "yyyy-MM-dd 'at' HH:mm:ss"), completion: { success in
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

extension FriendViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
