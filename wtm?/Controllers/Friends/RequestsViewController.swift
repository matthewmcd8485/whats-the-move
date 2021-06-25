//
//  RequestsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import UIKit
import Firebase
import AnyFormatKit
import PMAlertController
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
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        
        db.collection("users").document(uid).collection("friend requests").getDocuments() { [weak self] querySnapshot, error in
            guard error == nil else {
                return
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let uid = document.get("User Identifier") as! String
                let profileImageURL = document.get("Profile Image URL") as! String
                
                let user = FriendRequest(name: name.lowercased(), uid: uid, profileImageURL: profileImageURL)
                self?.requests.append(user)
                self?.tableView.reloadData()
                self?.updateUI()
            }
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
        
        let uid = UserDefaults.standard.string(forKey: "uid")
        let nameToAdd = requests[indexPath.row].name
        let uidToAdd = requests[indexPath.row].uid
        let profileImageURL = requests[indexPath.row].profileImageURL
        
        let alert = PMAlertController(title: "wow, you have friends!", description: "add \(nameToAdd) as a friend?", image: UIImage(systemName: "person.circle"), style: .alert)
        alert.alertImage.sd_setImage(with: URL.init(string: profileImageURL), completed: nil)
        alert.alertImage.contentMode = .scaleAspectFit
        //alert.alertImage.layer.cornerRadius = alert.alertImage.frame.width / 2
        
        alert.addAction(PMAlertAction(title: "accept", style: .default, action: { [weak self] in
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
        alert.addAction(PMAlertAction(title: "delete", style: .cancel, action: { [weak self] in
            self?.db.collection("users").document(uid!).collection("friend requests").document(uidToAdd).delete()
            self?.requests.removeAll()
            tableView.reloadData()
        }))
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel, action: nil))
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
        guard let myUID = UserDefaults.standard.string(forKey: "uid"), let myName = UserDefaults.standard.string(forKey: "name") else {
            return
        }
        
        // Add friend to personal Firestore collection
        db.collection("users").document(myUID).collection("friends").document(friendsUID).setData([
            "Name" : friendsName,
            "User Identifier" : friendsUID
        ], merge: true, completion: { [weak self] error in
            guard error == nil else {
                print("error adding friend to personal firestore: \(error!)")
                return
            }
            print("friend added to personal firestore!")

            // Add friend to friend's Firestore collection
            self?.db.collection("users").document(friendsUID).collection("friends").document(myUID).setData([
                "Name" : myName,
                "User Identifier" : myUID
            ], merge: true, completion: { error in
                guard error == nil else {
                    print("error adding friend to friend's firestore: \(error!)")
                    return
                }
                print("friend added to friend's firestore!")
                
                // Remove the pending friend request and reload the screen
                self?.db.collection("users").document(myUID).collection("friend requests").document(friendsUID).delete()
                self?.requests.remove(at: index)
                self?.tableView.reloadData()
                self?.updateUI()
            })
        })
    }
}

extension RequestsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
