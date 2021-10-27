//
//  SwooshViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/27/21.
//

import UIKit
import Firebase

class SwooshViewController: UIViewController {
    
    let db = Firestore.firestore()
    let databaseManager = DatabaseManager.shared
    let storageManager = StorageManager.shared
    
    let shape = CAShapeLayer()

    public var mood : NotificationTitle = .idk
    public var groups : [SelectableGroup] = []
    var allFriends : [Friend] = []
    var allUsers : [User] = []
    var groupNotification = [GroupNotification]()
    var sent = false
    
    @IBOutlet weak var sendingLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var checkmarkView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkmarkView.alpha = 0
        
        let circlePath = UIBezierPath(arcCenter: checkmarkView.center, radius: 120, startAngle: -(.pi / 2), endAngle: 3 * (.pi / 2), clockwise: true)
        circlePath.lineCapStyle = .round
        
        shape.path = circlePath.cgPath
        shape.lineWidth = 15
        shape.lineCap = .round
        
        shape.strokeColor = UIColor(red: 93 / 255, green: 138 / 255, blue: 166 / 255, alpha: 1.0).cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeEnd = 0
        view.layer.addSublayer(shape)
        
        sortUsers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        animate()
    }
    
    private func animate() {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        let timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.toValue = 1
        animation.duration = 1.5
        animation.timingFunction = timingFunction
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
            self.shape.add(animation, forKey: "animation")
        })
    }
    
    // MARK: - Sorting Users
    private func sortUsers() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            guard let strongSelf = self else {
                // Entering this block means the notifications were send successfully and the view has been removed, hence itself not existing
                print("Self doesn't exist")
                return
            }
            if !strongSelf.sent {
                AlertManager.shared.showAlert(title: "error sending notifications", message: "check your internet connection and try again.")
                self?.navigationController?.popViewController(animated: true)
                return
            }
        }
        
        let uid = UserDefaults.standard.string(forKey: "uid")
        let name = UserDefaults.standard.string(forKey: "name")
        for x in groups.count {
            for y in groups[x].friends.count {
                
                // Make sure they aren't you
                // Make sure you didn't block them
                // Make sure they didn't block you
                if groups[x].friends[y].uid != uid && !ReportingManager.shared.userBlockedYou(theirUID: groups[x].friends[y].uid) && !ReportingManager.shared.userIsBlocked(theirUID: groups[x].friends[y].uid) {
                    allFriends.append(groups[x].friends[y])
                }
            }
            
            //groupNotification[x].group = groups[x].group
            
            // Create a bored request in Firestore; one for each group
            let uuidString = UUID().uuidString
            let postedTime = NSDate(timeIntervalSinceNow: 0)
            let expiresAt = NSDate(timeIntervalSinceNow: 7200)
            db.collection("friend groups").document(groups[x].group.groupID).collection("bored requests").document(uuidString).setData([
                "Request Identifier" : uuidString,
                "Initiated By" : name!,
                "Posted Time" : postedTime,
                "Expires At" : expiresAt,
                "Activity" : mood.rawValue,
                "Group Identifier" : groups[x].group.groupID,
                "\(uid!) Availability" : "available",
                "\(uid!) Substatus" : "i'll be there!"
            ], merge: false, completion: { [weak self] error in
                guard error == nil else {
                    print("error uploading Firestore bored request for group: \(self!.groups[x].group.groupID)")
                    return
                }
            })
        }
        
        allFriends = allFriends.filterDuplicates { $0.uid == $1.uid }
        
        convert()
    }
    
    private func convert() {
        guard !allFriends.isEmpty else {
            print("allFriends list is empty")
            return
        }
        
        let group = DispatchGroup()
        
        for x in allFriends.count {
            group.enter()
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: allFriends[x].uid, completion: { [weak self] result in
                switch result {
                case.success(let user):
                    if user.status != "do not disturb" {
                        self?.allUsers.append(user)
                    }
                    group.leave()
                case.failure(let error):
                    print("\n\n\n *CONVERT FUNCTION* \n \n error downloading user: \(error)")
                }
            })
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.sendNotifications()
        }
    }
    
    private func sendNotifications() {
        guard !allUsers.isEmpty else {
            print("allUsers list is empty")
            return
        }
        
        let group = DispatchGroup()
        guard let name = UserDefaults.standard.string(forKey: "name"), let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }

        
        storageManager.downloadImageURL(imageName: mood.rawValue, collection: "mood images", completion: { [weak self] result in
            switch result {
            case .success(let imageURL):
                for x in self!.allUsers.count {
                    group.enter()
                    
                    let sender = PushNotificationSender()
                    if self?.allUsers[x].uid != uid {
                        sender.sendPushNotification(to: self!.allUsers[x].fcmToken, title: "new bored request", subtitle: "", body: "\(name) \(self!.mood.rawValue)", urlToImage: imageURL)
                    }
                    
                    group.leave()
                }
                
                group.notify(queue: .main) {
                    self?.sent = true
                    self?.finishUp()
                }
            case .failure(let error):
                print("error retrieving image URL: \(error)")
            }
        })
    }
    
    private func finishUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
            self?.sendingLabel.text = "done!"
            self?.subtitleLabel.text = "your boredom might be cured"
            
            UIView.animate(withDuration: 0.5) {
                    self?.checkmarkView.alpha = 1.0
                }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: {
            self.navigationController?.popToRootViewController(animated: true)
        })
    }

}
