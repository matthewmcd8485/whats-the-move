//
//  ImportContactsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import ContactsUI
import Firebase
import AnyFormatKit

class ImportContactsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db = Firestore.firestore()
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    var phoneContacts = [PhoneContact]()
    var filter: ContactsFilter = .message
    
    @IBOutlet weak var noContactsLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tableView.register(ImportedContactsTableViewCell.self, forCellReuseIdentifier: ImportedContactsTableViewCell.identifier)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        noContactsLabel.alpha = 0
        createSpinnerView()
        
        loadContacts(filter: filter)
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
    
    // MARK: - Loading Contacts
    func phoneNumberWithContryCode() -> [String] {
        let contacts = PhoneContacts.getContacts()
        var arrPhoneNumbers = [String]()
        for contact in contacts {
            for ContctNumVar: CNLabeledValue in contact.phoneNumbers {
                if let fulMobNumVar  = ContctNumVar.value as? CNPhoneNumber {
                    //let countryCode = fulMobNumVar.value(forKey: "countryCode") get country code
                    if let MccNamVar = fulMobNumVar.value(forKey: "digits") as? String {
                        arrPhoneNumbers.append(MccNamVar)
                    }
                }
            }
        }
        return arrPhoneNumbers // here array has all contact numbers.
    }
    
    private func loadContacts(filter: ContactsFilter) {
        phoneContacts.removeAll()
        var allContacts = [PhoneContact]()
        for contact in PhoneContacts.getContacts(filter: filter) {
            allContacts.append(PhoneContact(contact: contact))
        }
        
        var filterdArray = [PhoneContact]()
        if self.filter == .mail {
            filterdArray = allContacts.filter({ $0.email.count > 0 }) // getting all email
        } else if self.filter == .message {
            filterdArray = allContacts.filter({ $0.phoneNumber.count > 0 })
        } else {
            filterdArray = allContacts
        }
        phoneContacts.append(contentsOf: filterdArray)
        
        for contact in phoneContacts {
            print("Name -> \(contact.name!)")
            print("Email -> \(contact.email)")
            print("Phone Number -> \(contact.phoneNumber)")
        }
        let arrayCode  = self.phoneNumberWithContryCode()
        for codes in arrayCode {
            print(codes)
        }
        sortContacts()
    }
    
    private func sortContacts() {
        // Download list of all users
        var firestoreUsers = [User]()
        db.collection("users").getDocuments() { [weak self] querySnapshot, error in
            guard error == nil else {
                print("Error downloading user information from Firestore: \(error!)")
                return
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let status = document.get("Status") as! String
                let substatus = document.get("Substatus") as! String
                let profileImageURL = document.get("Profile Image URL") as? String ?? "no url"
                let fcmToken = document.get("FCM Token") as! String
                let joined = document.get("Joined") as! String
                let phoneNumber = document.get("Phone Number") as! String
                let uid = document.get("User Identifier") as! String
                
                let user = User(name: name, phoneNumber: phoneNumber, uid: uid, fcmToken: fcmToken, status: status, substatus: substatus, profileImageURL: profileImageURL, joinedTime: joined)
                
                firestoreUsers.append(user)
            }
            
            self?.phoneContacts.sort {
                $0.name!.lowercased() < $1.name!.lowercased()
            }
            
            // Sort through contacts list for phone numbers that appear in Firestore
            let formatter = DefaultTextInputFormatter(textPattern: "+# (###) ###-####")
            var sortedUsers = [PhoneContact]()
            for contact in self!.phoneContacts.count {
                for user in firestoreUsers.count {
                    var contactsPhoneNumber = (self!.phoneContacts[contact] as PhoneContact).phoneNumber[0]
                    if contactsPhoneNumber.count == 10 {
                        contactsPhoneNumber = "+1" + contactsPhoneNumber
                    } else if contactsPhoneNumber.count == 11 {
                        contactsPhoneNumber = "+" + contactsPhoneNumber
                    }
                    let firestorePhoneNumber = (firestoreUsers[user] as User).phoneNumber
                    if formatter.unformat(contactsPhoneNumber) ==  formatter.unformat(firestorePhoneNumber) {
                        sortedUsers.append(self!.phoneContacts[contact])
                    }
                }
            }
            
            sortedUsers = sortedUsers.filterDuplicates { $0.phoneNumber == $1.phoneNumber }
            let phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber")
            var removed = [PhoneContact]()
            for x in sortedUsers {
                if formatter.unformat(x.phoneNumber[0]) != formatter.unformat(phoneNumber) {
                    removed.append(x)
                }
            }
            
            self!.phoneContacts = removed
            
            self?.tableView.reloadData()
            
            if self?.phoneContacts.count == 0 {
                self?.tableView.isHidden = true
                UIView.animate(withDuration: 0.5) {
                    self?.noContactsLabel.alpha = 1
                    self?.loadingLabel.alpha = 0
                    self?.activityIndicator.alpha = 0
                }
            }
        }
    }
    

    
    // MARK: - Table View Delegates
    private func setupTableView() {
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        print(phoneContacts[indexPath.row].phoneNumber[0])
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "friendVerifyViewController") as FriendVerifyViewController
        vc.phoneNumber = phoneContacts[indexPath.row].phoneNumber[0]
        
        
        var formatter = DefaultTextFormatter(textPattern: "## (###) ###-####")
        
        if phoneContacts[indexPath.row].phoneNumber[0].count == 11 {
            formatter = DefaultTextFormatter(textPattern: "+# (###) ###-####")
            vc.phoneNumber = formatter.format(phoneContacts[indexPath.row].phoneNumber[0])!
        } else if phoneContacts[indexPath.row].phoneNumber[0].count == 10 {
            formatter = DefaultTextFormatter(textPattern: "+1 (###) ###-####")
            vc.phoneNumber = formatter.format(phoneContacts[indexPath.row].phoneNumber[0])!
        } else {
            vc.phoneNumber = formatter.format(phoneContacts[indexPath.row].phoneNumber[0])!
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return phoneContacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = phoneContacts[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ImportedContactsTableViewCell.identifier, for: indexPath) as! ImportedContactsTableViewCell
        cell.backgroundColor = UIColor(named: "backgroundColors")
        cell.accessoryType = .disclosureIndicator
        cell.contentView.clipsToBounds = true
        cell.configure(with: model)
        return cell
    }
}


extension ImportContactsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
