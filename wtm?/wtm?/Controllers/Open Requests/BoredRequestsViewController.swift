//
//  BoredRequestsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UIKit
import Firebase

class BoredRequestsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)

    public var groupsWithRequests = [BoredRequest]()
    public var groups = [FriendGroup]()
    
    var sortedGroups = [FriendGroup]()
    var sortedGroupsWithRequests = [BoredRequest]()

    @IBOutlet weak var noOneLabel: UILabel!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadingLabel.isHidden = false
        
        tableView.register(BoredRequestTableViewCell.self, forCellReuseIdentifier: BoredRequestTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.sectionHeaderHeight = 4.0
        tableView.sectionFooterHeight = 4.0
        
        tableView.isHidden = true
        noOneLabel.isHidden = false
        
        createSpinnerView()
        //configureUI()
        //loadFriendGroups()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUI()
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
    
    // MARK: - Loading Requests
    private func loadFriendGroups() {
        groups.removeAll()
        groupsWithRequests.removeAll()
        
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
                self?.groups = downloadedGroups
                UserDefaults.standard.set(groupIDs, forKey: "groupsUID")
                self?.loadBoredRequests()
            case .failure(let error):
                print("\n *GROUPS VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
    private func loadBoredRequests() {
        groupsWithRequests.removeAll()
        guard let groupIDs = UserDefaults.standard.stringArray(forKey: "groupsUID") else {
            print("groupsUID array is empty (load bored requests)")
            return
        }
        
        // 7200 seconds was two hours ago
        let expiredCutoff = Timestamp(date: Date(timeInterval: TimeInterval(-7200), since: Date()))
        for x in groupIDs.count {
            db.collection("friend groups").document(groupIDs[x]).collection("bored requests").whereField("Posted Time", isGreaterThanOrEqualTo: expiredCutoff).getDocuments() { [weak self] querySnapshot, error in
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
                    print(request)
                    self?.groupsWithRequests.append(request)
                    
                    self?.groupsWithRequests = self!.groupsWithRequests.filterDuplicates { $0.requestID == $1.requestID }
                    
                    
                }
                
                if self?.groupsWithRequests.count != 0 {
                    self?.sortGroupsAndRequests()
                }
            }
        }
        
    }
    
    // MARK: - Sorting Data
    private func sortGroupsAndRequests() {
        sortedGroups.removeAll()
        sortedGroupsWithRequests.removeAll()
        
        for x in groupsWithRequests.count {
            for y in groups.count {
                if groupsWithRequests[x].groupID == groups[y].groupID {
                    sortedGroups.append(groups[y])
                    sortedGroupsWithRequests.append(groupsWithRequests[x])
                }
            }
        }
        tableView.reloadData()
        configureUI()
    }
    
    @IBAction func reloadButton(_ sender: Any) {
        configureUI()
        loadFriendGroups()
    }
    
    private func configureUI() {
        if groupsWithRequests.count == 0 {
            tableView.isHidden = true
            loadingLabel.isHidden = true
            activityIndicator.isHidden = true
            noOneLabel.isHidden = false
            view.bringSubviewToFront(noOneLabel)
        } else {
            tableView.isHidden = false
            loadingLabel.isHidden = true
            activityIndicator.isHidden = true
            noOneLabel.isHidden = true
            view.bringSubviewToFront(tableView)
        }
    }
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return sortedGroupsWithRequests.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "boredRequestResponseViewController") as BoredRequestResponseViewController
        
        vc.group = sortedGroups[indexPath.section]
        vc.request = sortedGroupsWithRequests[indexPath.section]
        
        
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BoredRequestTableViewCell.identifier, for: indexPath) as! BoredRequestTableViewCell
        
        let model = sortedGroupsWithRequests[indexPath.section]
        let group = sortedGroups[indexPath.section]
        
        cell.backgroundColor = .black
        cell.selectionStyle = .none
        cell.contentView.clipsToBounds = true
        cell.configure(model: model, group: group)
        
        return cell
    }
}
