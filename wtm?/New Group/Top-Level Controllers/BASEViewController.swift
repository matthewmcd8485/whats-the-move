//
//  BASEViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//



/*
 
 Use this dummy ViewController when creating a new class.
 
 It should save time on the setup process.
 
 Don't forget to change the class name and remove/add TableView functions as needed.
 
*/

import UIKit
import Firebase

class BASEViewController: UIViewController {

    let db = Firestore.firestore()
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        createSpinnerView()
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
}

extension BASEViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
