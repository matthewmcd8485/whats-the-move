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
                self?.updateUI()
                self?.configureStatusView()
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
            
            let storageRef = Storage.storage().reference().child("profile images").child("\(friend.uid!) - profile image.png")
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
}

extension FriendViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
