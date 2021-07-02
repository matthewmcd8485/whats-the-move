//
//  GroupDetailViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//

import UIKit
import Firebase
import PMAlertController

class GroupDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let reportingManager = ReportingManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    public var groupID = ""
    var groupMembers = [User]()
    var group = FriendGroup(name: "", groupID: "", people: [String]())
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var peopleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tableView.alpha = 0
        loadingLabel.alpha = 1
        peopleLabel.text = ""
        nameLabel.text = ""
        
        tableView.register(FriendsTableViewCell.self, forCellReuseIdentifier: FriendsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        createSpinnerView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadGroup()
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    private func createSpinnerView() {
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: loadingLabel.frame.maxY + 50, width: 20, height: 20)
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(tableView)
        //spinner.hudView.frame = CGRect(x: view.center.x, y: view.center.y - 120, width: 50, height: 50)
        //spinner.show(in: view)
        
    }
    
    // MARK: - Loading Group
    private func loadGroup() {
        db.collection("friend groups").whereField("Group Identifier", isEqualTo: groupID).getDocuments() { [weak self] querySnapshot, error in
            guard error == nil else {
                print("error loading group: \(error!)")
                return
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let groupID = document.get("Group Identifier") as! String
                let people = document.get("People") as! [String]

                self?.group = FriendGroup(name: name, groupID: groupID, people: people)
                self?.loadUsers()
            }
        }
    }
    
    private func loadUsers() {
        DispatchQueue.global().async(execute: {
            DispatchQueue.main.sync { [weak self] in
                for x in self!.group.people!.count {
                    self?.databaseManager.downloadUser(where: "User Identifier", isEqualTo: self!.group.people![x], completion: { result in
                        switch result {
                        case .success(let user):
                            
                            if user.uid != UserDefaults.standard.string(forKey: "uid") {
                                self?.groupMembers.append(user)
                                self?.groupMembers = self!.groupMembers.filterDuplicates { $0.uid == $1.uid }
                                self?.groupMembers.sort { $0.name! < $1.name! }
                            }
                            
                            self?.tableView.reloadData()
                            self?.updateUI()
                        case .failure(let error):
                            self?.cancelOperation()
                            print(error)
                        }
                    })
                }
            }
        })
    }
    
    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            if self?.groupMembers.count == 0 {
                UIView.animate(withDuration: 0.5, animations: {
                    self?.peopleLabel.alpha = 0
                    self?.tableView.alpha = 0
                    self?.nameLabel.alpha = 0
                })
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self?.loadingLabel.alpha = 0
                    self?.tableView.alpha = 1
                    self?.peopleLabel.alpha = 1
                    self?.nameLabel.alpha = 1
                    
                    if self?.groupMembers.count == 1 {
                        self?.peopleLabel.text = "1 other person in this group"
                    } else {
                        self?.peopleLabel.text = "\(self!.groupMembers.count) other people in this group"
                    }
                    self?.nameLabel.text = self?.group.name
                })
            }
        }
    }
    
    private func cancelOperation() {
        let alert = PMAlertController(title: "group members not found", description: "we appear to be stuck inside a white void where your group members don't exist. \n \n or maybe you just don't have any friends?", image: nil, style: .alert)
        let action = PMAlertAction(title: "rude, but okay", style: .default, action: {
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func leaveGroupButton(_ sender: Any) {
        let uid = UserDefaults.standard.string(forKey: "uid")
        let alert = PMAlertController(title: "leave group", description: "are you sure you want to leave this group?", image: nil, style: .alert)
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
        alert.addAction(PMAlertAction(title: "leave", style: .default, action: { [weak self] in
            
            let document = self?.db.collection("friend groups").document(self!.group.groupID)
            document?.updateData([
                "People": FieldValue.arrayRemove([uid!])
            ], completion: { error in
                guard error == nil else {
                    print("error removing user from group: \(error!)")
                    return
                }
                
                self?.navigationController?.popViewController(animated: true)
            })
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let uid = UserDefaults.standard.string(forKey: "uid")
        
        // Check if the selected user is in your friends list
        var isFriend = false
        guard let friendsUID = UserDefaults.standard.stringArray(forKey: "friendsUID") else {
            print("friendsUID array is empty")
            alertManager.showAlert(title: "error loading user", message: "there was a problem loading in the person you selected. maybe they're just a fake friend?")
            return
        }
        for x in friendsUID.count {
            if groupMembers[indexPath.row].uid == friendsUID[x] {
                isFriend = true
            }
        }
        
        // Check if the selected user is yourself
        if groupMembers[indexPath.row].uid != uid {
            if isFriend {
                // This person is already your friend
                
                // Check if they are blocked
                if reportingManager.userIsBlocked(theirUID: groupMembers[indexPath.row].uid!) || reportingManager.userBlockedYou(theirUID: groupMembers[indexPath.row].uid!) {
                    alertManager.showAlert(title: "user blocked", message: "either you blocked this person, or they blocked you.\n\n quit it wth these toxic friends!")
                } else {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(identifier: "friendViewController") as FriendViewController
                    vc.friendsUID = groupMembers[indexPath.row].uid!
                    navigationController?.pushViewController(vc, animated: true)
                }
            } else {
                // This person is not your friend
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "friendVerifyViewController") as FriendVerifyViewController
                vc.phoneNumber = groupMembers[indexPath.row].phoneNumber!
                vc.comingFromGroup = true
                navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            alertManager.showAlert(title: "chill out, dude", message: "you can't stalk yourself, weirdo.")
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupMembers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = groupMembers[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendsTableViewCell.identifier, for: indexPath) as! FriendsTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
}

extension GroupDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
