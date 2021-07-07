//
//  HomeScreenViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase
import PMAlertController

class HomeScreenViewController: UIViewController {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared

    @IBOutlet weak var saveThemButton: UIButton!
    @IBOutlet weak var someoneIsBoredLabel: UILabel!
    @IBOutlet weak var boredButtonLayer: UIButton!
    
    var boredButtonHasMoved = false
    public var groups = [FriendGroup]()
    public var groupsWithRequests = [BoredRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        saveThemButton.layer.cornerRadius = 10
        
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        navigationController?.viewControllers = [self]
        
        saveThemButton.alpha = 0
        someoneIsBoredLabel.alpha = 0
        
        loadFriendGroups()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        configureUI()
        loadBoredRequests()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        //configureUI()
        //loadBoredRequests()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)

    }
    
    private func configureUI() {
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            if self!.groupsWithRequests.count > 0 {
                self?.saveThemButton.alpha = 1
                self?.someoneIsBoredLabel.alpha = 1
                self?.boredButtonLayer.transform = CGAffineTransform(translationX: 0, y: 30)
                self?.boredButtonHasMoved = true
            } else {
                self?.saveThemButton.alpha = 0
                self?.someoneIsBoredLabel.alpha = 0
                if self!.boredButtonHasMoved {
                    self?.boredButtonLayer.transform = CGAffineTransform(translationX: 0, y: -30)
                    self?.boredButtonHasMoved = false
                }
            }
        })
    }
    
    private func loadFriendGroups() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        
        groups.removeAll()
        
        db.collection("friend groups").whereField("People", arrayContains: uid).getDocuments() { [weak self] querySnapshot, error in
            guard error == nil else {
                return
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let groupID = document.get("Group Identifier") as! String
                let people = document.get("People") as! [String]
                
                let group = FriendGroup(name: name.lowercased(), groupID: groupID, people: people)
                self?.groups.append(group)
                self?.groups = self!.groups.filterDuplicates { $0.groupID == $1.groupID }
                self?.groups.sort { $0.name < $1.name }
            }
            
            self?.loadBoredRequests()
        }
    }
    
    private func loadBoredRequests() {
        groupsWithRequests.removeAll()
        
        // 7200 seconds was two hours ago
        let expiredCutoff = Timestamp(date: Date(timeInterval: TimeInterval(-7200), since: Date()))
        for x in groups.count {
            db.collection("friend groups").document(groups[x].groupID).collection("bored requests").whereField("Posted Time", isGreaterThanOrEqualTo: expiredCutoff).getDocuments() { [weak self] querySnapshot, error in
                guard error == nil else {
                    print(error!)
                    return
                }
                
                for document in querySnapshot!.documents {
                    let activity = document.get("Activity") as! String
                    let postedTimestamp = document.get("Posted Time") as! Timestamp
                    let expiresTimestamp = document.get("Expires At") as! Timestamp
                    let initiatedBy = document.get("Initiated By") as! String
                    let groupID = document.get("Group Identifier") as! String
                    let requestID = document.get("Request Identifier") as! String
                    
                    let postedTime = postedTimestamp.dateValue()
                    let expiresAt = expiresTimestamp.dateValue()
                    
                    let request = BoredRequest(groupID: groupID, requestID: requestID, activity: activity, postedTime: postedTime, expiresAt: expiresAt, initiatedBy: initiatedBy, people: [BoredRequestUser]())
                    self?.groupsWithRequests.append(request)
                    
                    self?.groupsWithRequests = self!.groupsWithRequests.filterDuplicates { $0.requestID == $1.requestID }
                }
                
                if querySnapshot?.documents.count != 0 {
                    self?.configureUI()
                }
            }
        }
        
    }
    
    @IBAction func saveThemButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "boredRequestsViewController") as BoredRequestsViewController
        vc.groupsWithRequests = groupsWithRequests
        vc.groups = groups
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func boredButton(_ sender: Any) {
        guard groups.count != 0 else {
            //alertManager.showAlert(title: "no friend groups", message: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.")
            
            let alert = PMAlertController(title: "no friend groups", description: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.", image: nil, style: .alert)
            alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
            alert.addAction(PMAlertAction(title: "okay", style: .cancel))
            alert.addAction(PMAlertAction(title: "take me there", style: .default, action: { [weak self] in
                self?.tabBarController?.selectedIndex = 0
            }))
            
            present(alert, animated: true)
            return
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "activityViewController") as ActivityViewController
        navigationController?.pushViewController(vc, animated: true)
    }
}
