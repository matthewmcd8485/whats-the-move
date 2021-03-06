//
//  FriendGroupsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit
import Firebase
import PMAlertController

class FriendGroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let profanityManager = ProfanityManager.shared
    
    var groups = [FriendGroup]()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noGroupsLabel: UILabel!
    @IBOutlet weak var groupButton: UIButton!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        groupButton.layer.cornerRadius = 10
        
        noGroupsLabel.isHidden = true
        loadingLabel.isHidden = false
        
        tableView.register(FriendGroupsTableViewCell.self, forCellReuseIdentifier: FriendGroupsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        
        createSpinnerView()
        //loadFriendGroups()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadFriendGroups()
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
        var groupIDs = [String]()
        
        databaseManager.downloadAllGroups(uid: uid, completion: { [weak self] result in
            switch result {
            case .success(let downloadedGroups):
                for x in downloadedGroups.count {
                    groupIDs.append(downloadedGroups[x].groupID)
                }
                UserDefaults.standard.set(groupIDs, forKey: "groupsUID")
                self?.groups = downloadedGroups
                self?.tableView.reloadData()
                self?.updateUI()
            case .failure(let error):
                print("\n *GROUPS VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
    @IBAction func newGroupButton(_ sender: Any) {
        let friendsCount = UserDefaults.standard.integer(forKey: "friendsCount")
        if friendsCount < 2 {
            alertManager.showAlert(title: "slow your roll", message: "you need to have at least two friends to create a friend group. nice try, though.")
        } else {
            let alert = PMAlertController(title: "name group", description: "enter a name for the new group.", image: nil, style: .alert)
            alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
            alert.alertTitle.textColor = UIColor(named: "lightBrown")!
            alert.addTextField { (textField) in
                textField?.autocapitalizationType = .none
                let placeholder = "ex. the dream team"
                textField!.attributedPlaceholder = NSAttributedString(string: placeholder, attributes:
                                                                        [NSAttributedString.Key.foregroundColor : UIColor.lightGray])
                textField?.placeholder = placeholder
            }
            alert.addAction(PMAlertAction(title: "save", style: .default, action: { [weak self] in
                let textField = alert.textFields[0]
                guard textField.text != nil && textField.text != "" else {
                    return
                }
                
                if self!.profanityManager.checkForProfanity(in: textField.text!) {
                    self?.alertManager.showAlert(title: "ok, potty mouth", message: "there are some less-than-ideal words used in your group name. please make sure it is appropriate.")
                } else {
                    let lowercasedName = textField.text!.lowercased()
                    let whitespaceName = lowercasedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    self?.createGroup(name: whitespaceName)
                }
            }))
            alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
            present(alert, animated: true)
            
        }
    }
    
    func createGroup(name: String) {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        
        let UUID = UUID().uuidString
        db.collection("friend groups").document(UUID).setData([
            "Group Identifier" : UUID,
            "Name" : name,
            "People" : [uid]
        ], merge: true, completion: { [weak self] error in
            guard error == nil else {
                print("error: \(error!)")
                return
            }
            
            print("group created")
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "groupDetailViewController") as! GroupDetailViewController
            vc.groupID = UUID
            self?.navigationController?.pushViewController(vc, animated: true)
            
        })
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
        return 65
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "groupDetailViewController") as GroupDetailViewController
        vc.groupID = groups[indexPath.row].groupID
        navigationController?.pushViewController(vc, animated: true)
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
