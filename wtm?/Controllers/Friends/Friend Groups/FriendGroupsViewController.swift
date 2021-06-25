//
//  FriendGroupsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit
import Firebase

class FriendGroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    var groups = [FriendGroup]()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noGroupsLabel: UILabel!
    @IBOutlet weak var groupButton: UIButton!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        groupButton.layer.cornerRadius = 10
        
        noGroupsLabel.isHidden = true
        loadingLabel.isHidden = false
        
        tableView.register(FriendGroupsTableViewCell.self, forCellReuseIdentifier: FriendGroupsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        
        createSpinnerView()
        loadFriendGroups()
        
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
    
    private func loadFriendGroups() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        
        db.collection("friend groups").whereField("People", arrayContains: uid).getDocuments() { [weak self] querySnapshot, error in
            guard error == nil else {
                return
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let groupID = document.get("Group Identifier") as! String
                let people = document.get("People") as! [String]
                
                let user = FriendGroup(name: name.lowercased(), groupID: groupID, people: people)
                self?.groups.append(user)
                self?.tableView.reloadData()
                self?.updateUI()
            }
        }
        
        if groups.count == 0 {
            tableView.reloadData()
            updateUI()
        }
    }
    
    @IBAction func newGroupButton(_ sender: Any) {
        let friendsCount = UserDefaults.standard.integer(forKey: "friendsCount")
        if friendsCount < 2 {
            alertManager.showAlert(title: "slow your roll", message: "you need to have at least two friends to create a friend group. nice try, though.")
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "createGroupViewController") as CreateGroupViewController
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func updateUI() {
        loadingLabel.isHidden = true
        activityIndicator.isHidden = true
        
        if groups.count > 0 {
            tableView.isHidden = false
            noGroupsLabel.isHidden = true
        } else {
            tableView.isHidden = true
            noGroupsLabel.isHidden = false
        }
        
    }
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = groups[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendGroupsTableViewCell.identifier, for: indexPath) as! FriendGroupsTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }

}

extension FriendGroupsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
