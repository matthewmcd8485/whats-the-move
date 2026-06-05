//
//  FriendSelectionViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/26/21.
//

import UIKit
import FirebaseFirestore

class FriendSelectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    public var mood: NotificationTitle = .idk
    var groups = [SelectableGroup]()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        sendButton.layer.cornerRadius = 10
        
        tableView.register(FriendGroupsTableViewCell.self, forCellReuseIdentifier: FriendGroupsTableViewCell.identifier)
        
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        
        createSpinnerView()
        loadGroups()
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
    
    // MARK: - Load Groups
    private func loadGroups() {
        guard let uid = SecureStorage.uid else {
            return
        }
        
        groups.removeAll()
        
        databaseManager.downloadAllGroups(uid: uid) { [weak self] result in
            switch result {
            case .failure(let error):
                print("error downloading groups: \(error)")
                return
            case .success(let groups):
                for group in groups {
                    guard let people = group.people else { continue }
                    self?.databaseManager.downloadFriends(fromGroupWith: people, completion: { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(let friends):
                            let selectableGroup = SelectableGroup(group: group, friends: friends, isSelected: false)
                            
                            for x in 0..<selectableGroup.friends.count {
                                print(selectableGroup.friends[x].name)
                            }
                            
                            self.groups.append(selectableGroup)
                            self.groups = self.groups.filterDuplicates { $0.group.groupID == $1.group.groupID }
                            self.groups.sort { $0.group.name < $1.group.name }
                            
                            self.tableView.reloadData()
                            self.updateUI()
                        case .failure(let error):
                            print("error downloading friends: \(error)")
                        }
                    })
                }
            }
        }

    }
    
    private func loadFriends(in group: FriendGroup) -> [User] {
        var friends = [User]()
        for x in 0..<group.people!.count {
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: group.people![x], completion: { result in
                switch result {
                case .success(let user):
                    print(user)
                    friends.append(user)
                    friends = friends.filterDuplicates { $0.uid == $1.uid }
                    friends.sort { $0.name < $1.name }
                case .failure(let error):
                    print("error loading friends in group \(group.groupID): \n \(error)")
                }
            })
        }
        return friends
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            if self.groups.count > 0 {
                self.tableView.isHidden = false
                self.activityIndicator.isHidden = true
                self.loadingLabel.isHidden = true
            } else {
                self.tableView.isHidden = true
                self.activityIndicator.isHidden = true
                self.loadingLabel.isHidden = true
            }
        }
    }
    
    // MARK: - Send Notification
    @IBAction func sendButton(_ sender: Any) {
        //var groupsToSendTo : [SelectableGroup] = []
        //
        //for x in groups.count {
        //    if groups[x].isSelected {
        //        groupsToSendTo.append(groups[x])
        //    }
        //}
        //
        //if groupsToSendTo.isEmpty {
        //    alertManager.showAlert(title: "no group selected", message: "really have no friends huh?")
        //} else {
        //    let storyboard = UIStoryboard(name: "Main", bundle: nil)
        //    let vc = storyboard.instantiateViewController(identifier: "swooshViewController") as SwooshViewController
        //    vc.mood = mood
        //    vc.groups = groupsToSendTo
        //    navigationController?.pushViewController(vc, animated: true)
        //}
        
        let alert = UIAlertController(title: "are you sure?", message: "don't be annoying if you don't have to. \n\ndoing this will disable your sending privileges for two hours.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "let's do this", style: .default, handler: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            // Log the time that this was done
            UserDefaults.standard.setValue(Date(), forKey: "sendToAllDate")

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "swooshViewController") as SwooshViewController
            vc.mood = strongSelf.mood
            vc.groups = strongSelf.groups
            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "nevermind, cancel", style: .cancel, handler: nil))

        present(alert, animated: true)
    }
    
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "swooshViewController") as SwooshViewController
        vc.mood = mood
        vc.groups = [groups[indexPath.row]]
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = groups[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendGroupsTableViewCell.identifier, for: indexPath) as! FriendGroupsTableViewCell
        
        //cell.surfaceButton.addTarget(self, action: #selector(checkMarkButtonClicked(sender:)), for: .touchUpInside)
        
        // if cell.surfaceButton.isSelected {
        //    cell.checkmarkImageView.image = UIImage(named: "Checkmark")
        //    groups[indexPath.row].isSelected = true
        //} else {
        //    cell.checkmarkImageView.image = UIImage(named: "EmptyCircle")
        //    groups[indexPath.row].isSelected = false
        //}
        
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.contentView.clipsToBounds = true
        cell.configure(with: model.group)
        return cell
    }
    
    @objc private func checkMarkButtonClicked(sender: UIButton) {
        if sender.isSelected {
            sender.isSelected = false
            
        } else {
            sender.isSelected = true
        }
        tableView.reloadData()
    }
}

extension FriendSelectionViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
