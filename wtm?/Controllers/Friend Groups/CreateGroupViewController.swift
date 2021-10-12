//
//  CreateGroupViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit
import Firebase

class CreateGroupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let profanityManager = ProfanityManager.shared
    
    var friends = [SelectableUser]()
    var friendsInGroup = [String]()
    var selectedArray = [IndexPath]()
    var currentIndexPath = IndexPath()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var textField: UITextField!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        createButton.layer.cornerRadius = 10
        
        loadingLabel.isHidden = false
        
        tableView.register(CreateFriendGroupTableViewCell.self, forCellReuseIdentifier: CreateFriendGroupTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isHidden = true
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        createSpinnerView()
        loadFriends()
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
    
    // MARK: - Load Friends
    private func loadFriends() {
        guard let friendsUIDs = UserDefaults.standard.stringArray(forKey: "friendsUID") else {
            updateUI()
            return
        }
        
        friends.removeAll()
        
        for x in friendsUIDs.count {
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: friendsUIDs[x], completion: { [weak self] result in
                switch result {
                case .success(let user):
                    if !ReportingManager.shared.userIsBlocked(theirUID: user.uid) && !ReportingManager.shared.userBlockedYou(theirUID: user.uid) {
                        self?.friends.append(SelectableUser(user: user, isSelected: false))
                        self?.friends = self!.friends.filterDuplicates { $0.user.uid == $1.user.uid }
                        self?.friends.sort { $0.user.name < $1.user.name }
                    }
                case .failure(let error):
                    self?.alertManager.showAlert(title: "error loading friends", message: "there was an error loading your friends from the database. \n \n maybe you just don't have any?")
                    print(error)
                }
                
                UserDefaults.standard.set(self?.friends.count, forKey: "friendsCount")
                self?.tableView.reloadData()
                self?.updateUI()
            })
        }
        
        if friends.count == 0 {
            tableView.reloadData()
            updateUI()
        }
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            if self.friends.count > 0 {
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
    
    @IBAction func createButton(_ sender: Any) {
        let groupName = textField.text ?? ""
        
        friendsInGroup.removeAll()
        
        let uid = UserDefaults.standard.string(forKey: "uid")
        friendsInGroup.append(uid!)
        for x in friends.count {
            if friends[x].isSelected {
                friendsInGroup.append(friends[x].user.uid)
            }
        }
        if groupName == "" {
            alertManager.showAlert(title: "no group name provided", message: "please enter a group name in the field.")
        } else if friendsInGroup.count < 3 {
            alertManager.showAlert(title: "group is too small", message: "groups need to have at least two other people. unless you don't have two friends, in which case we're sorry for you.")
        } else {
            if profanityManager.checkForProfanity(in: groupName) {
                alertManager.showAlert(title: "ok, potty mouth", message: "there are some less-than-ideal words used in your group's name. please make sure it is appropriate.")
            } else {
                // Upload data to Firestore
                
                let UUID = UUID().uuidString
                db.collection("friend groups").document(UUID).setData([
                    "Group Identifier" : UUID,
                    "Name" : groupName,
                    "People" : friendsInGroup
                ], merge: true, completion: { [weak self] error in
                    guard error == nil else {
                        print("error: \(error!)")
                        return
                    }
                    
                    print("group created")
                    self?.navigationController?.popViewController(animated: true)
                    
                })
            }
        }
    }
    
    // MARK: - Text Field Delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.dequeueReusableCell(withIdentifier: CreateFriendGroupTableViewCell.identifier, for: indexPath) as! CreateFriendGroupTableViewCell
        tableView.deselectRow(at: indexPath, animated: true)
        if selectedArray.contains(indexPath) {
            if let index = selectedArray.firstIndex(of: indexPath) {
                selectedArray.remove(at: index)
            }
        } else {
            selectedArray.append(indexPath)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = friends[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: CreateFriendGroupTableViewCell.identifier, for: indexPath) as! CreateFriendGroupTableViewCell
        cell.surfaceButton.addTarget(self, action: #selector(checkMarkButtonClicked(sender:)), for: .touchUpInside)
        currentIndexPath = indexPath
        
        if selectedArray.contains(indexPath) {
            cell.checkmarkImageView.image = UIImage(named: "Checkmark")
            friends[indexPath.row].isSelected = true
        } else {
            cell.checkmarkImageView.image = UIImage(named: "EmptyCircle")
            friends[indexPath.row].isSelected = false
        }
        
        /*
        for x in friends.count {
            if friends[x].isSelected {
                cell.checkmarkImageView.image = UIImage(named: "Checkmark")
            } else {
                cell.checkmarkImageView.image = UIImage(named: "EmptyCircle")
            }
        }
        */
        
        print("selected index paths: \(selectedArray)")
        
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.contentView.clipsToBounds = true
        cell.selectionStyle = .default
        cell.configure(with: model)
        return cell
    }
    
    @objc private func checkMarkButtonClicked(sender: UIButton) {
        //tableView.deselectRow(at: indexPath, animated: true)
        if selectedArray.contains(currentIndexPath) {
            if let index = selectedArray.firstIndex(of: currentIndexPath) {
                selectedArray.remove(at: index)
            }
        } else {
            selectedArray.append(currentIndexPath)
        }
        
       // if sender.isSelected {
       //     sender.isSelected = false
       //
       // } else {
       //     sender.isSelected = true
       // }
        tableView.reloadData()
    }
    
}

extension CreateGroupViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
