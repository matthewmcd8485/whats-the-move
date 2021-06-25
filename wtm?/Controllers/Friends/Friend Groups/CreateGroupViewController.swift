//
//  CreateGroupViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit
import Firebase

class CreateGroupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    var friends = [User]()
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var createButton: UIButton!
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        createButton.layer.cornerRadius = 10
        
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        
        loadingLabel.isHidden = false
        
        tableView.register(CreateFriendGroupTableViewCell.self, forCellReuseIdentifier: CreateFriendGroupTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.setEditing(true, animated: true)
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
                    self?.friends.append(user)
                    self?.friends = self!.friends.filterDuplicates { $0.uid == $1.uid }
                    self?.friends.sort { $0.name! < $1.name! }
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
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //tableView.deselectRow(at: indexPath, animated: true)
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = friends[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: CreateFriendGroupTableViewCell.identifier, for: indexPath) as! CreateFriendGroupTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        true
    }
    
    func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        //tableView.setEditing(true, animated: true)
    }
    
    func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        print("editing ended")
    }
}

extension CreateGroupViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
