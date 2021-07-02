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
    
    let shape = CAShapeLayer()

    public var mood : NotificationTitle = .idk
    public var groups : [SelectableGroup] = []
    var allFriends : [Friend] = []
    var allUsers : [User] = []
    
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
        let uid = UserDefaults.standard.string(forKey: "uid")
        for x in groups.count {
            for y in groups[x].friends.count {
                
                // Make sure they aren't you
                // Make sure you didn't block them
                // Make sure they didn't block you
                if groups[x].friends[y].uid != uid && !ReportingManager.shared.userBlockedYou(theirUID: groups[x].friends[y].uid) && !ReportingManager.shared.userIsBlocked(theirUID: groups[x].friends[y].uid) {
                    allFriends.append(groups[x].friends[y])
                }
            }
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
        let name = UserDefaults.standard.string(forKey: "name")
        
        for x in allUsers.count {
            group.enter()
            
            let sender = PushNotificationSender()
            sender.sendPushNotification(to: allUsers[x].fcmToken!, title: "\(name!) \(mood.rawValue)", body: "do them a favor and fix their boredom")
            
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.finishUp()
        }
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
