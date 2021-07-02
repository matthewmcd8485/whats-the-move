//
//  ReportingManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//

import Foundation
import Firebase

final class ReportingManager {
    
    static let shared = ReportingManager()
    
    let firestore = Firestore.firestore()
    
    // Checks a cached array to see if a particular user is blocked
    public func userIsBlocked(theirUID: String) -> Bool {
        let blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? [""]
        
        guard !blockedUsers.isEmpty else {
            return false
        }
        
        if let blockedUser = blockedUsers.first(where: { $0 == theirUID }) {
            print("\(blockedUser) is blocked; removing this user from results.")
            return true
        }
        
        return false
    }
    
    // Checks a cached array to see if a particular user blocked you
    public func userBlockedYou(theirUID: String) -> Bool {
        let whoBlockedMe = UserDefaults.standard.stringArray(forKey: "whoBlockedMe") ?? [""]
        
        guard !whoBlockedMe.isEmpty else {
            return false
        }
        
        if let blockedUser = whoBlockedMe.first(where: { $0 == theirUID }) {
            print("\(blockedUser) blocked you; removing them from results.")
            return true
        }
        
        return false
    }
    
    // Adds an external user's account to a "Reported Users" collection on Firestore
    public func reportUser(uid: String, name: String, date: String, completion: @escaping (Bool) -> Void) {
        firestore.collection("reported users").document("\(uid)_\(date)").setData([
            "User Identifier" : uid,
            "Reported Date" : date,
            "User Name" : name
        ], merge: false, completion: { error in
            guard error == nil else {
                print("Error reporting user: \(error!)")
                completion(false)
                return
            }
            completion(true)
        })
    }
}
