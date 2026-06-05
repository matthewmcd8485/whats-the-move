//
//  RequestsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import UIKit
import FirebaseFirestore
import AnyFormatKit
import SDWebImage

class RequestsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    var requests = [FriendRequest]()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noOneLabel: UILabel!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        noOneLabel.isHidden = true
        loadingLabel.isHidden = false
        
        tableView.register(RequestsTableViewCell.self, forCellReuseIdentifier: RequestsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        
        createSpinnerView()
        loadRequests()
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
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    private func loadRequests() {
        guard let uid = SecureStorage.uid else {
            return
        }
        
        DatabaseManager.shared.downloadFriendRequests(uid: uid) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("error loading friend requests: \(error)")
            case .success(let requests):
                let lowercased = requests.map {
                    FriendRequest(name: $0.name.lowercased(), uid: $0.uid, profileImageURL: $0.profileImageURL)
                }
                self.requests = lowercased.filter { !ReportingManager.shared.userIsBlocked(theirUID: $0.uid) }
            }
            self.tableView.reloadData()
            self.updateUI()
        }
    }
    
    private func updateUI() {
        loadingLabel.isHidden = true
        activityIndicator.isHidden = true
        
        if requests.count > 0 {
            tableView.isHidden = false
            noOneLabel.isHidden = true
        } else {
            tableView.isHidden = true
            noOneLabel.isHidden = false
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
        
        let uid = SecureStorage.uid
        let nameToAdd = requests[indexPath.row].name
        let uidToAdd = requests[indexPath.row].uid
        
        let alert = UIAlertController(title: "wow, you have friends!", message: "add \(nameToAdd) as a friend?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "accept", style: .default, handler: { [weak self] _ in
            if let friendsUID = UserDefaults.standard.stringArray(forKey: "friendsUID"), let friendsName = UserDefaults.standard.stringArray(forKey: "friendsName") {
                var friendsAddUID = friendsUID
                var friendsAddName = friendsName
                friendsAddUID.append(uidToAdd)
                friendsAddName.append(nameToAdd)
                UserDefaults.standard.set(friendsAddUID, forKey: "friendsUID")
                UserDefaults.standard.set(friendsAddName, forKey: "friendsName")
                self?.addFriendToDatabase(with: uidToAdd, friendsName: nameToAdd, index: indexPath.row)
                //self?.navigationController?.popViewController(animated: true)
            } else {
                UserDefaults.standard.set([uidToAdd], forKey: "friendsUID")
                UserDefaults.standard.set([nameToAdd], forKey: "friendsName")
                self?.addFriendToDatabase(with: uidToAdd, friendsName: nameToAdd, index: indexPath.row)
                //self?.navigationController?.popViewController(animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "delete", style: .destructive, handler: { [weak self] _ in
            DatabaseManager.shared.deleteFriendRequest(forUID: uid!, fromUID: uidToAdd)
            self?.requests.removeAll()
            tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = requests[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: RequestsTableViewCell.identifier, for: indexPath) as! RequestsTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
    
    // MARK: - Adding Friend
    private func addFriendToDatabase(with friendsUID: String, friendsName: String, index: Int) {
        guard let myUID = SecureStorage.uid, let myName = UserDefaults.standard.string(forKey: "name") else {
            return
        }
        
        DatabaseManager.shared.acceptFriendRequest(myUID: myUID, myName: myName, friendUID: friendsUID, friendName: friendsName, completion: { [weak self] result in
            switch result {
            case .failure(let error):
                print("error accepting friend request: \(error)")
                return
            case .success:
                print("friend added to both Firestore collections; request cleared")
                self?.requests.remove(at: index)
                self?.tableView.reloadData()
                self?.updateUI()
            }
        })
    }
}

extension RequestsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
