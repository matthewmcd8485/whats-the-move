//
//  MyFriendsViewController.swift
//  wtm?
//
//  Now a thin host for `MyFriendsView` (SwiftUI). The IBOutlets/IBAction remain
//  declared so the storyboard scene loads cleanly, but the storyboard-built
//  subviews are hidden and a SwiftUI host fills the screen.
//

import UIKit
import SwiftUI

class MyFriendsViewController: UIViewController {

    @IBOutlet weak var addFriendsButton: UIButton?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var noFriendsLabel: UILabel?
    @IBOutlet weak var loadingLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide everything the storyboard set up — SwiftUI takes over.
        view.subviews.forEach { $0.isHidden = true }
        view.backgroundColor = UIColor(named: "backgroundColors")

        let rootView = MyFriendsView(
            onSelectFriend: { [weak self] user in
                self?.pushFriendDetail(uid: user.uid, name: user.name)
            },
            onTapRequests: { [weak self] in
                self?.pushRequests()
            },
            onTapAddFriends: { [weak self] in
                self?.pushAddFriends()
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // Storyboard still wires this @IBAction selector on the (now-hidden) button.
    // Kept as a stub so the storyboard load succeeds; SwiftUI invokes the same
    // navigation via `onTapRequests`.
    @IBAction func requestsButton(_ sender: Any) {
        pushRequests()
    }

    // MARK: - Navigation
    private func pushFriendDetail(uid: String, name: String) {
        if name == "user deleted" {
            AlertManager.shared.showAlert(title: "user deleted", message: "sorry, we don't specialize in communicating with ghosts.")
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "friendViewController") as FriendViewController
        vc.friendsUID = uid
        navigationController?.pushViewController(vc, animated: true)
    }

    private func pushRequests() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "requestsViewController") as RequestsViewController
        navigationController?.pushViewController(vc, animated: true)
    }

    private func pushAddFriends() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "addFriendsViewController") as! AddFriendsViewController
        navigationController?.pushViewController(vc, animated: true)
    }
}
