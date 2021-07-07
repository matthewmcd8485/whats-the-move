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
    
    var sortedGroupsWithRequests = [BoredRequest]()
    var sortedGroups = [FriendGroup]()

    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        loadingLabel.isHidden = false
        
        tableView.register(BoredRequestTableViewCell.self, forCellReuseIdentifier: BoredRequestTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.sectionHeaderHeight = 4.0
        tableView.sectionFooterHeight = 4.0
        
        tableView.isHidden = true
        
        createSpinnerView()
        loadStuff()
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
    
    private func loadStuff() {
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
    
    private func configureUI() {
        tableView.isHidden = false
        loadingLabel.isHidden = true
        activityIndicator.isHidden = true
    }
    
    // MARK: - TableView Delegates
    func numberOfSections(in tableView: UITableView) -> Int {
        return sortedGroups.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "boredRequestResponseViewController") as BoredRequestResponseViewController
        vc.group = sortedGroups[indexPath.section]
        vc.request = groupsWithRequests[indexPath.section]
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = sortedGroupsWithRequests[indexPath.section]
        let group = sortedGroups[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: BoredRequestTableViewCell.identifier, for: indexPath) as! BoredRequestTableViewCell
        cell.backgroundColor = .black
        cell.selectionStyle = .none
        cell.contentView.clipsToBounds = true
        cell.configure(model: model, group: group)
        return cell
    }
}

extension BoredRequestsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
