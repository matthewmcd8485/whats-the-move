//
//  SwooshViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/27/21.
//

import UIKit
import FirebaseFirestore

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
        
        let uid = SecureStorage.uid
        let name = UserDefaults.standard.string(forKey: "name")
        for x in 0..<groups.count {
            for y in 0..<groups[x].friends.count {
                
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
            let postedTime = Date(timeIntervalSinceNow: 0)
            let expiresAt = Date(timeIntervalSinceNow: 7200)
            databaseManager.createBoredRequest(
                requestID: uuidString,
                groupID: groups[x].group.groupID,
                initiatedBy: name!,
                postedTime: postedTime,
                expiresAt: expiresAt,
                activity: mood.rawValue,
                initiatorUID: uid!,
                initiatorSubstatus: "i'll be there!",
                completion: { [weak self] result in
                    guard let self = self else { return }
                    if case .failure(let error) = result {
                        print("error uploading Firestore bored request for group: \(self.groups[x].group.groupID): \(error)")
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
        
        for x in 0..<allFriends.count {
            group.enter()
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: allFriends[x].uid, completion: { [weak self] result in
                defer { group.leave() }
                switch result {
                case .success(let user):
                    if user.status != "do not disturb" {
                        self?.allUsers.append(user)
                    }
                case .failure(let error):
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
        
        // Note: client-side FCM fan-out was removed (the legacy HTTP send path
        // was unauthenticated and silently 401'd). Push notifications should
        // be sent by a Cloud Function triggered on bored-request creation.
        // For now we just verify the mood image still exists and finish up.
        storageManager.downloadImageURL(imageName: mood.rawValue, collection: "mood images", completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.sent = true
                self.finishUp()
            case .failure(let error):
                print("error retrieving image URL: \(error)")
                AlertManager.shared.showAlert(title: "couldn't send", message: "there was a problem sending your bored request. please try again.")
                self.navigationController?.popViewController(animated: true)
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
