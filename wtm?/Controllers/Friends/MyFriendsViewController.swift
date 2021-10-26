//
//  MyFriendsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Contacts
import Firebase

class MyFriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let db = Firestore.firestore()
    private let alertManager = AlertManager.shared
    private let databaseManager = DatabaseManager.shared
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()
    
    var friends = [User]()
    
    @IBOutlet weak var addFriendsButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noFriendsLabel: UILabel!
    @IBOutlet weak var loadingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addFriendsButton.layer.cornerRadius = 10
        
        tableView.isHidden = true
        loadingLabel.isHidden = false
        noFriendsLabel.isHidden = true
        
        tableView.register(FriendsTableViewCell.self, forCellReuseIdentifier: FriendsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        createSpinnerView()
        setupRefreshControl()
        loadFriends()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        //createSpinnerView()
        //setupRefreshControl()
        //loadFriends()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @IBAction func requestsButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "requestsViewController") as RequestsViewController
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func setupRefreshControl() {
        let string = "loading friends..."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "SuperBasic-Regular", size: 10)!,
        ]
        
        refreshControl.attributedTitle = NSAttributedString(string: string, attributes: attributes)
        refreshControl.backgroundColor = UIColor(named: "backgroundColors")
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        refreshControl.addTarget(self, action: #selector(refreshTableView(_:)), for: .valueChanged)
    }
    
    @objc private func refreshTableView(_ sender: Any) {
        updateGlobalFriendsList()
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
    
    // MARK: - Loading Friends
    private func updateGlobalFriendsList() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        var uids = [String]()
        
        databaseManager.downloadAllFriends(uid: uid, completion: { result in
            switch result {
            case .success(let users):
                for x in users.count {
                    uids.append(users[x].uid)
                }
                UserDefaults.standard.set(uids, forKey: "friendsUID")
                self.loadFriends()
            case .failure(let error):
                print("\n *FRIENDS VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
    private func loadFriends() {
        guard let friendsUIDs = UserDefaults.standard.stringArray(forKey: "friendsUID") else {
            updateUI()
            return
        }
        
        //friends.removeAll()
        //tableView.reloadData()
        
        for x in friendsUIDs.count {
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: friendsUIDs[x], completion: { [weak self] result in
                switch result {
                case .success(let user):
                    if !ReportingManager.shared.userIsBlocked(theirUID: user.uid) && !ReportingManager.shared.userBlockedYou(theirUID: user.uid) && user.name != "user deleted" {
                        self?.friends.append(user)
                        self?.friends = self!.friends.filterDuplicates { $0.uid == $1.uid }
                        self?.friends.sort { $0.name < $1.name }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
            if self?.friends.count == 0 {
                self?.tableView.reloadData()
                self?.updateUI()
            }
        })
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            if self.friends.count > 0 {
                self.tableView.isHidden = false
                self.activityIndicator.isHidden = true
                self.noFriendsLabel.isHidden = true
                self.loadingLabel.isHidden = true
            } else {
                self.tableView.isHidden = true
                self.activityIndicator.isHidden = true
                self.noFriendsLabel.isHidden = false
                self.loadingLabel.isHidden = true
            }
        }
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
        
        if friends[indexPath.row].name == "user deleted" {
            alertManager.showAlert(title: "user deleted", message: "sorry, we don't specialize in communicating with ghosts.")
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "friendViewController") as FriendViewController
            vc.friendsUID = friends[indexPath.row].uid
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if friends.count != 0 {
            let model = friends[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendsTableViewCell.identifier, for: indexPath) as! FriendsTableViewCell
            cell.backgroundColor = UIColor(named: "backgroundColors")
            cell.accessoryType = .disclosureIndicator
            cell.contentView.clipsToBounds = true
            cell.configure(with: model)
            return cell
        }
        return UITableViewCell()
    }
}

