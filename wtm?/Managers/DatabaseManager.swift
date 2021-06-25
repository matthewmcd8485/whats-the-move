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
    
    // MARK: - Download Users In Subcollection
    public func downloadUsersInSubcollection(uid: String, subcollection: String, completion: @escaping (Result<[User], Error>) -> Void){
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
    
    public func downloadAllFriends(uid: String, completion: @escaping (Result<[Friend], Error>) -> Void){
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
}
