//
//  SubstatusViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import Firebase

class SubstatusViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    public var status: String = ""
    @IBOutlet weak var tableView: UITableView!
    
    let db = Firestore.firestore()
    let uid = UserDefaults.standard.string(forKey: "uid")!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tableView.register(SubstatusTableViewCell.self, forCellReuseIdentifier: SubstatusTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        setupTableView()
    }
    
    // MARK: - Substatus Arrays
    var array: [String] = [""]
    let availableSubstatuses = ["ready to mingle", "literally so bored", "let's do something!", "hmu!", "need something to do", "this app is dumb"]
    let busySubstatuses = ["already have plans", "will be free later", "not on my phone today", "don't know what's happening", "tied up at work", "this app is dumb"]
    let dndSubstatuses = ["don't talk to me", "i don't like you", "i'm not free today", "call me when i care", "leave me alone", "this app is dumb"]
    
    // MARK: - Table View Delegates
    private func setupTableView() {
        if status == "available" {
            array = availableSubstatuses
            tableView.reloadData()
        } else if status == "busy" {
            array = busySubstatuses
        } else {
            array = dndSubstatuses
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(array[indexPath.row], forKey: "substatus")
        tableView.deselectRow(at: indexPath, animated: true)
        
        db.collection("users").document(uid).setData([
            "Status" : status,
            "Substatus" : array[indexPath.row]
        ], merge: true, completion: { [weak self] error in
            guard error == nil else {
                print("Error updating status in Firestore: \(error!)")
                return
            }
            
            // Document successfully written
            self?.navigationController?.popToRootViewController(animated: true)
        })
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return array.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = array[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: SubstatusTableViewCell.identifier, for: indexPath) as! SubstatusTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

}

extension SubstatusViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
