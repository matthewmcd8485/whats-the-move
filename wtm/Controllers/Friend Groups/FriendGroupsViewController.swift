//
//  FriendGroupsViewController.swift
//  wtm?
//
//  Now a thin host for `FriendGroupsView` (SwiftUI). Storyboard outlets remain
//  declared so loading the scene doesn't crash, but the storyboard-built
//  subviews are hidden and a SwiftUI host fills the screen.
//

import UIKit
import SwiftUI

class FriendGroupsViewController: UIViewController {

    @IBOutlet weak var loadingLabel: UILabel?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var noGroupsLabel: UILabel?
    @IBOutlet weak var groupButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.subviews.forEach { $0.isHidden = true }
        view.backgroundColor = UIColor(named: "backgroundColors")

        let rootView = FriendGroupsView(
            onSelectGroup: { [weak self] group in
                self?.pushGroupDetail(groupID: group.groupID)
            },
            onCreateGroup: { [weak self] name in
                self?.createGroup(name: name)
            }
        )

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    // Storyboard still wires this @IBAction. SwiftUI's "new group" button
    // hits `onCreateGroup` directly, so this is just a safety stub.
    @IBAction func newGroupButton(_ sender: Any) {}

    // MARK: - Navigation
    private func pushGroupDetail(groupID: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "groupDetailViewController") as GroupDetailViewController
        vc.groupID = groupID
        navigationController?.pushViewController(vc, animated: true)
    }

    private func createGroup(name: String) {
        guard let uid = SecureStorage.uid else { return }
        DatabaseManager.shared.createGroup(name: name, ownerUID: uid) { [weak self] result in
            switch result {
            case .failure(let error):
                print("error creating group: \(error)")
            case .success(let newGroupID):
                self?.pushGroupDetail(groupID: newGroupID)
            }
        }
    }
}
