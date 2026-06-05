//
//  CreateGroupViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit
import Firebase

class AddPeopleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let profanityManager = ProfanityManager.shared
    
    var friends = [User]()
    var friendsInGroup = [String]()
    var selectedArray = [IndexPath]()
    var currentIndexPath = IndexPath()
    
    public var completion: ((String) -> (Void))?
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        loadingLabel.isHidden = false
        
        tableView.register(FriendsTableViewCell.self, forCellReuseIdentifier: FriendsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isHidden = true
        
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
        completion!(friends[indexPath.row].uid)
        navigationController?.popViewController(animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = friends[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendsTableViewCell.identifier, for: indexPath) as! FriendsTableViewCell
        
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.contentView.clipsToBounds = true
        cell.accessoryType = .disclosureIndicator
        cell.configure(with: model)
        return cell
    }
    
}

extension AddPeopleViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
