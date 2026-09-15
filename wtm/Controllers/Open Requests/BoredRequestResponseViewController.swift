//
//  BoredRequestResponseViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/3/21.
//

import UIKit
import FirebaseFirestore

class BoredRequestResponseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let reportingManager = ReportingManager.shared
    
    public var group = FriendGroup()
    public var request = BoredRequest()
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
  
    @IBOutlet weak var replyButton: UIButton!
    @IBOutlet weak var bakgroundView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var expiresAtLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tableView.alpha = 0
        loadingLabel.isHidden = false
        replyButton.layer.cornerRadius = 10
        
        tableView.register(BoredResponseTableViewCell.self, forCellReuseIdentifier: BoredResponseTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        configureBackgroundImageView()
        configureLabels()
        createSpinnerView()
        loadUsers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    // MARK: - UI Configuration
    private func configureLabels() {
        if group.isDirectGroup {
            groupNameLabel.text = request.initiatedBy
            activityLabel.text = request.activity
        } else {
            groupNameLabel.text = group.name
            activityLabel.text = "\(request.initiatedBy) \(request.activity)"
        }

        let expiringTime = request.expiresAt.toString(dateFormat: "h:mm a")
        expiresAtLabel.text = "this request expires at \(expiringTime)"
    }
    
    private func configureBackgroundImageView() {
        // Image
        var image = UIImage(named: "chill")
        
        if request.activity == "wants to get coffee" {
            image = UIImage(named: "coffee")
        } else if request.activity == "is hungry" {
            image = UIImage(named: "food")
        } else if request.activity == "wants ice cream" {
            image = UIImage(named: "ice cream")
        } else if request.activity == "wants to go to the store" {
            image = UIImage(named: "store")
        } else if request.activity == "wants to go to the mall" {
            image = UIImage(named: "mall")
        } else if request.activity == "wants to go downtown" {
            image = UIImage(named: "city")
        } else if request.activity == "wants to go swimming" {
            image = UIImage(named: "swimming")
        } else if request.activity == "wants to go outside" {
            image = UIImage(named: "outdoors")
        } else if request.activity == "wants to play sports" {
            image = UIImage(named: "sports")
        } else if request.activity == "wants to workout" {
            image = UIImage(named: "workout")
        } else if request.activity == "wants to stare at you" {
            image = UIImage(named: "stare")
        } else if request.activity == "is bored" {
            image = UIImage(named: "idk")
        } else if request.activity == "wants to play with a dog" {
            image = UIImage(named: "dog")
        } else if request.activity == "wants to watch a movie" {
            image = UIImage(named: "movie")
        } else if request.activity == "wants to chill" {
            image = UIImage(named: "chill")
        } else if request.activity == "wants to drive around" {
            image = UIImage(named: "drive")
        } else if request.activity == "wants to sleep with you" {
            image = UIImage(named: "sleepover")
        } else if request.activity == "wants a kiss" {
            image = UIImage(named: "date night")
        }
        
        backgroundImageView.image = image
        
        // Gradient layer on backgroundImageView
        let maskLayer = CAGradientLayer(layer: backgroundImageView.layer)
        maskLayer.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        maskLayer.frame = backgroundImageView.bounds
        backgroundImageView.layer.mask = maskLayer
        
        // Gradient layer on backgroundView
        let maskLayer2 = CAGradientLayer(layer: bakgroundView.layer)
        maskLayer2.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        maskLayer2.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer2.endPoint = CGPoint(x: 0.5, y: 1.0)
        maskLayer2.frame = bakgroundView.bounds
        bakgroundView.layer.mask = maskLayer2
        bakgroundView.alpha = 0.7
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
    
    @IBAction func replyButton(_ sender: Any) {
        respondToRequest()
    }
    
    // MARK: - Load Users
    private func loadUsers() {
        // Download users in the group
        guard let people = group.people else { return }
        let totalPeople = people.count
        
        for x in 0..<totalPeople {
            databaseManager.downloadUser(where: "User Identifier", isEqualTo: people[x], completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let user):
                    let boredUser = BoredRequestUser(user: user, responseStatus: "", responseSubstatus: "")
                    self.request.people.append(boredUser)
                    
                    if x == totalPeople - 1 {
                        self.downloadResponses()
                    }
                case .failure(let error):
                    self.alertManager.showAlert(title: "error loading friends", message: "there was an error loading your friends from the database. \n \n maybe you just don't have any?")
                    print(error)
                }
            })
        }
        
    }
    
    private func downloadResponses() {
        db.collection(FirestoreKeys.Collection.friendGroups).document(group.groupID).collection(FirestoreKeys.Collection.boredRequests).whereField(FirestoreKeys.BoredRequest.requestIdentifier, isEqualTo: request.requestID).getDocuments() { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard error == nil else {
                print("error downloading request: \(error!)")
                return
            }
            
            guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                let alert = UIAlertController(title: "error loading request", message: "there was an error loading this request. please try again later.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "okay", style: .default, handler: { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }))
                self.present(alert, animated: true)
                
                print("querySnapshot for responses is empty [downloadResponses()]")
                return
            }
            
            for document in documents {
                for x in 0..<self.request.people.count {
                    let id = self.request.people[x].user.uid
                    let response = document.get(FirestoreKeys.BoredRequest.availabilityField(forUID: id)) as? String ?? "no response"
                    let substatus = document.get(FirestoreKeys.BoredRequest.substatusField(forUID: id)) as? String ?? "no response"
                    
                    self.request.people[x].responseStatus = response
                    self.request.people[x].responseSubstatus = substatus
                }
            }
            
            self.tableView.reloadData()
            self.tableView.alpha = 1
            self.loadingLabel.alpha = 0
            self.activityIndicator.alpha = 0
        }
    }
    
    // MARK: - Edit Response
    private func showResponseEditScreen(status: String) {
        let uid = SecureStorage.uid
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "changeResponseViewController") as ChangeResponseViewController
        vc.status = status
        vc.completion = { [weak self] result in
            guard let self = self else { return }
            guard result != "" else {
                return
            }
            
            for x in 0..<self.request.people.count {
                if self.request.people[x].user.uid == uid {
                    // Change local UI immediately
                    self.request.people[x].responseStatus = status
                    self.request.people[x].responseSubstatus = result
                    
                    // Upload changes to Firebase
                    self.databaseManager.updateBoredRequestResponse(groupID: self.group.groupID, requestID: self.request.requestID, uid: uid!, status: status, substatus: result, completion: { [weak self] updateResult in
                        switch updateResult {
                        case .failure(let error):
                            print("error updating response in Firebase: \(error)")
                            return
                        case .success:
                            self?.notifyFriends(status: status, substatus: result)
                            self?.tableView.reloadData()
                        }
                    })
                }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func notifyFriends(status: String, substatus: String) {
        guard let name = UserDefaults.standard.string(forKey: "name") else {
            return
        }
        
        var notificationTitle = "\(name) is in!"
        if status == "busy" {
            notificationTitle = "\(name) might be busy"
        } else if status == "not available" {
            notificationTitle = "\(name) is not available"
        }
        
        // Note: client-side FCM fan-out removed; push notifications need a
        // Cloud Function trigger on response updates. The compose logic for
        // notificationTitle/substatus stays in place for when that lands.
        _ = notificationTitle
        _ = substatus
    }
    
    private func respondToRequest() {
        let alert = UIAlertController(title: "change your response", message: "are you free today?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "yeah, i'm free", style: .default, handler: { [weak self] _ in
            self?.showResponseEditScreen(status: "available")
        }))
        alert.addAction(UIAlertAction(title: "mmm, maybe?", style: .default, handler: { [weak self] _ in
            self?.showResponseEditScreen(status: "busy")
        }))
        alert.addAction(UIAlertAction(title: "no, i'm not free", style: .default, handler: { [weak self] _ in
            self?.showResponseEditScreen(status: "not available")
        }))
        alert.addAction(UIAlertAction(title: "oops, cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
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
        
        let uid = SecureStorage.uid
        if request.people[indexPath.row].user.uid == uid {
            
            // Reply to your own request
            respondToRequest()
        } else if request.people[indexPath.row].user.name == "user deleted" {
            // This user doesn't exist anymore
            alertManager.showAlert(title: "user deleted", message: "sorry, we don't specialize in communicating with ghosts.")
        } else {
            // Check if the selected user is in your friends list
            var isFriend = false
            guard let friendsUID = UserDefaults.standard.stringArray(forKey: "friendsUID") else {
                print("friendsUID array is empty")
                alertManager.showAlert(title: "error loading user", message: "there was a problem loading in the person you selected. maybe they're just a fake friend?")
                return
            }
            for x in 0..<friendsUID.count {
                if request.people[indexPath.row].user.uid == friendsUID[x] {
                    isFriend = true
                }
            }
            
            // Check if they are blocked
            if reportingManager.userIsBlocked(theirUID: request.people[indexPath.row].user.uid) || reportingManager.userBlockedYou(theirUID: request.people[indexPath.row].user.uid) {
                alertManager.showAlert(title: "user blocked", message: "either you blocked this person, or they blocked you.\n\n quit it wth these toxic friends!")
            } else {
                // Check if they are your friend
                if isFriend {
                    // Show the friend screen
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(identifier: "friendViewController") as FriendViewController
                    vc.friendsUID = request.people[indexPath.row].user.uid
                    navigationController?.pushViewController(vc, animated: true)
                } else {
                    // Show the add friend screen
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(identifier: "friendVerifyViewController") as FriendVerifyViewController
                    vc.phoneNumber = request.people[indexPath.row].user.phoneNumber
                    vc.comingFromGroup = true
                    navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return request.people.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = request.people[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: BoredResponseTableViewCell.identifier, for: indexPath) as! BoredResponseTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
    
}

extension BoredRequestResponseViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

