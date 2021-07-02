//
//  DatabaseManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import Foundation
import Firebase

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    
    // MARK: - Download User
    public func downloadUser(where field: String, isEqualTo: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection("users").whereField(field, isEqualTo: isEqualTo).getDocuments() { querySnapshot, error in
            if let error = error  {
                print("Error loading user from Firebase: \(error)")
                completion(.failure(DatabaseError.failedToFetch))
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let status = document.get("Status") as! String
                let substatus = document.get("Substatus") as! String
                let profileImageURL = document.get("Profile Image URL") as! String
                let fcmToken = document.get("FCM Token") as! String
                let joined = document.get("Joined") as! String
                let phoneNumber = document.get("Phone Number") as! String
                let uid = document.get("User Identifier") as! String
                
                let user = User(name: name, phoneNumber: phoneNumber, uid: uid, fcmToken: fcmToken, status: status, substatus: substatus, profileImageURL: profileImageURL, joinedTime: joined)
                completion(.success(user))
            }
        }
    }
    
    // MARK: - Update FCM Token
    public func updateFCMToken(uid: String, newToken: String) {
        db.collection("users").document(uid).setData([
            "FCM Token" : newToken
        ], merge: true, completion: { error in
            guard error == nil else {
                print("Error creating user in Firestore: \(error!)")
                return
            }
            
        })
    }
    
    // MARK: - Download Users In Subcollection
    public func downloadUsersInSubcollection(uid: String, subcollection: String, completion: @escaping (Result<[User], Error>) -> Void) {
        var users = [User]()
        
        db.collection("users").document(uid).collection(subcollection).getDocuments() { querySnapshot, error in
            if let error = error  {
                print("Error loading friends from Firebase: \(error)")
                completion(.failure(DatabaseError.failedToFetch))
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let status = document.get("Status") as! String
                let substatus = document.get("Substatus") as! String
                let profileImageURL = document.get("Profile Image URL") as! String
                let fcmToken = document.get("FCM Token") as! String
                let joined = document.get("Joined") as! String
                let phoneNumber = document.get("Phone Number") as! String
                let uid = document.get("User Identifier") as! String
                
                let user = User(name: name, phoneNumber: phoneNumber, uid: uid, fcmToken: fcmToken, status: status, substatus: substatus, profileImageURL: profileImageURL, joinedTime: joined)
                users.append(user)
            }
            completion(.success(users))
        }
    }
    
    // MARK: - Download All Friends
    public func downloadAllFriends(uid: String, completion: @escaping (Result<[Friend], Error>) -> Void) {
        var users = [Friend]()
        
        db.collection("users").document(uid).collection("friends").getDocuments() { querySnapshot, error in
            if let error = error  {
                print("Error loading friends from Firebase: \(error)")
                completion(.failure(DatabaseError.failedToFetch))
            }
            
            for document in querySnapshot!.documents {
                let name = document.get("Name") as! String
                let uid = document.get("User Identifier") as! String
                
                let user = Friend(name: name, uid: uid)
                users.append(user)
            }
            completion(.success(users))
        }
    }
    
    // MARK: - Download Friends In Group
    public func downloadFriends(fromGroupWith: [String], completion: @escaping (Result<[Friend], Error>) -> Void) {
        var friendsReturn = [Friend]()
        
        for x in fromGroupWith.count {
            db.collection("users").whereField("User Identifier", isEqualTo: fromGroupWith[x]).getDocuments() { querySnapshot, error in
                if let error = error  {
                    print("Error loading friends from Firebase: \(error)")
                    completion(.failure(DatabaseError.failedToFetch))
                }
                
                for document in querySnapshot!.documents {
                    let name = document.get("Name") as! String
                    let uid = document.get("User Identifier") as! String
                    
                    let friend = Friend(name: name, uid: uid)
                    friendsReturn.append(friend)
                }
                
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            if friendsReturn.count > 0 {
                completion(.success(friendsReturn))
            } else {
                completion(.failure(DatabaseError.failedToFetch))
            }
        })
    }
    
    // MARK: - Block User
    // Adds an external user's email to the current user's "Blocked Users" subcollection
    public func blockUser(uidToBlock: String, completion: @escaping (Bool) -> Void) {
        
        // Update local cache of blocked users
        var blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? [String]()
        blockedUsers.append(uidToBlock)
        UserDefaults.standard.set(blockedUsers, forKey: "blockedUsers")
        
        // Update Firestore collection of blocked users
        let uid = UserDefaults.standard.string(forKey: "uid")!
        let date = Date().toString(dateFormat: "yyyy-MM-dd 'at' HH:mm:ss")
        
        db.collection("blocked users").document(uidToBlock).setData([
            "Blocking User's Identifier" : uid,
            "Blocked User's Identifier" : uidToBlock,
            "Blocked On" : date
        ], merge: false, completion: { error in
            guard error == nil else {
                print("Error blocking user: \(error!)")
                completion(false)
                return
            }
            print("user blocked!")
            completion(true)
        })
    }
    
    // MARK: - Update Blocked Users List
    // Updates a cached array of all blocked users for a given user
    public func updateBlockedUsersList(uid: String, completion: @escaping (Bool) -> Void) {
        UserDefaults.standard.set([""], forKey: "blockedUsers")
        UserDefaults.standard.set([""], forKey: "whoBlockedMe")
        
        var blockedUsers: [String] = [""]
        var whoBlockedMe: [String] = [""]
        db.collection("blocked users").whereField("Blocked User's Identifier", isEqualTo: uid).getDocuments() { (snapshot, error) in
            guard error == nil else {
                print("Error accessing blocked users subcollection: \(error!)")
                completion(false)
                return
            }
            
            for document in snapshot!.documents {
                let blockedMe = document.get("Blocking User's Identifier") as! String
                whoBlockedMe.append(blockedMe)
            }
            UserDefaults.standard.set(whoBlockedMe, forKey: "whoBlockedMe")
        }
        
        db.collection("blocked users").whereField("Blocking User's Identifier", isEqualTo: uid).getDocuments() { (snapshot, error) in
            guard error == nil else {
                print("Error accessing blocked users subcollection: \(error!)")
                completion(false)
                return
            }
            
            for document in snapshot!.documents {
                let blockedYou = document.get("Blocked User's Identifier") as! String
                blockedUsers.append(blockedYou)
            }
            UserDefaults.standard.set(blockedUsers, forKey: "blockedUsers")
            completion(true)
        }
    }
}
