//
//  ChangeResponseViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/3/21.
//

import UIKit
import Firebase
import PMAlertController

class ChangeResponseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db = Firestore.firestore()
    let uid = UserDefaults.standard.string(forKey: "uid")!
    
    public var completion: ((String) -> (Void))?
    public var status: String = ""

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var statusImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tableView.register(SubstatusTableViewCell.self, forCellReuseIdentifier: SubstatusTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupTableView()
    }

    
    // MARK: - Substatus Arrays
    var array: [String] = [""]
    let availableSubstatuses = ["lmk what time", "sounds good", "i'll be there!", "i'll drive", "on my way!", "ok!", "so excited!", "can't wait to see you all", "joe"]
    let busySubstatuses = ["already have plans", "maybe later?", "tomorrow would work better", "don't know what's happening", "maybe when i get off work", "gotta ask my parents", "won't have a car today", "ask me again in an hour", "joe"]
    let dndSubstatuses = ["already have plans today", "i'm not in town", "i don't like you", "i'm not free today", "call me when i care", "leave me alone", "at work all day", "got dragged into some other stuff", "joe"]
    
    // MARK: - Table View Delegates
    private func setupTableView() {
        if status == "available" {
            statusImageView.image = UIImage(systemName: "checkmark.circle")
            statusImageView.tintColor = UIColor.systemGreen
            statusLabel.text = "you are available"
            array = availableSubstatuses
        } else if status == "busy" {
            statusImageView.image = UIImage(systemName: "exclamationmark.circle")
            statusImageView.tintColor = UIColor(named: "darkYellowOnLight")
            statusLabel.text = "you are busy"
            array = busySubstatuses
        } else {
            statusImageView.image = UIImage(systemName: "nosign")
            statusImageView.tintColor = UIColor.systemRed
            statusLabel.text = "you are not available"
            array = dndSubstatuses
        }
        
        tableView.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        completion!(array[indexPath.row])
        navigationController?.popViewController(animated: true)
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

extension ChangeResponseViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
