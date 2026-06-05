//
//  DatabaseManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import Foundation
import FirebaseFirestore

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    let db = Firestore.firestore()
    
    // MARK: - Download User
    public func downloadUser(where field: String, isEqualTo: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).whereField(field, isEqualTo: isEqualTo).getDocuments() { querySnapshot, error in
            if let error = error  {
                Log.database.error("Error loading user from Firebase: \(error.localizedDescription, privacy: .public)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            do {
                let user = try documents[0].data(as: User.self)
                completion(.success(user))
            } catch {
                Log.database.error("Error decoding User from Firestore: \(error.localizedDescription, privacy: .public)")
                completion(.failure(DatabaseError.failedToFetch))
            }
        }
    }
    
    // MARK: - Update FCM Token
    public func updateFCMToken(uid: String, newToken: String) {
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.fcmToken : newToken
        ], merge: true, completion: { error in
            guard error == nil else {
                Log.database.error("Error creating user in Firestore: \(error!.localizedDescription, privacy: .public)")
                return
            }
            
        })
    }
    
    // MARK: - Create / Update User Profile
    public func createUser(_ user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(user.uid).setData([
            FirestoreKeys.User.name : user.name,
            FirestoreKeys.User.phoneNumber : user.phoneNumber,
            FirestoreKeys.User.userIdentifier : user.uid,
            FirestoreKeys.User.fcmToken : user.fcmToken,
            FirestoreKeys.User.status : user.status,
            FirestoreKeys.User.substatus : user.substatus,
            FirestoreKeys.User.joined : user.joinedTime,
            FirestoreKeys.User.profileImageURL : user.profileImageURL
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func updateUserName(uid: String, name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.name : name
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func updateUserStatus(uid: String, status: String, substatus: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.status : status,
            FirestoreKeys.User.substatus : substatus
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func updateUserProfileImageURL(uid: String, url: String) {
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.profileImageURL : url
        ], merge: true)
    }
    
    // MARK: - Soft-delete User
    public func softDeleteUserProfile(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let deletedMarker = "user deleted"
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.name : deletedMarker,
            FirestoreKeys.User.phoneNumber : deletedMarker,
            FirestoreKeys.User.profileImageURL : deletedMarker,
            FirestoreKeys.User.joined : deletedMarker,
            FirestoreKeys.User.fcmToken : deletedMarker,
            FirestoreKeys.User.status : deletedMarker,
            FirestoreKeys.User.substatus : deletedMarker
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func softDeleteFriendReferences(toUID uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collectionGroup(FirestoreKeys.Collection.friends).whereField(FirestoreKeys.User.userIdentifier, isEqualTo: uid).getDocuments { (snapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = snapshot?.documents else {
                completion(.success(()))
                return
            }
            for document in documents {
                document.reference.setData([
                    FirestoreKeys.User.name : "user deleted"
                ], merge: true)
            }
            completion(.success(()))
        }
    }
    
    // MARK: - Bored Requests
    public func createBoredRequest(requestID: String, groupID: String, initiatedBy: String, postedTime: Date, expiresAt: Date, activity: String, initiatorUID uid: String, initiatorSubstatus substatus: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).document(requestID).setData([
            FirestoreKeys.BoredRequest.requestIdentifier : requestID,
            FirestoreKeys.BoredRequest.initiatedBy : initiatedBy,
            FirestoreKeys.BoredRequest.postedTime : postedTime,
            FirestoreKeys.BoredRequest.expiresAt : expiresAt,
            FirestoreKeys.BoredRequest.activity : activity,
            FirestoreKeys.BoredRequest.groupIdentifier : groupID,
            FirestoreKeys.BoredRequest.availabilityField(forUID: uid) : "available",
            FirestoreKeys.BoredRequest.substatusField(forUID: uid) : substatus
        ], merge: false, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func downloadBoredRequests(forGroupIDs groupIDs: [String], notExpiredSince expiredCutoff: Timestamp, completion: @escaping (Result<[BoredRequest], Error>) -> Void) {
        guard !groupIDs.isEmpty else {
            completion(.success([]))
            return
        }
        
        var allRequests = [BoredRequest]()
        let group = DispatchGroup()
        
        for groupID in groupIDs {
            group.enter()
            db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).whereField(FirestoreKeys.BoredRequest.postedTime, isGreaterThanOrEqualTo: expiredCutoff).getDocuments() { querySnapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    Log.database.error("error loading bored requests for group \(groupID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                for document in documents {
                    guard
                        let activity = document.get(FirestoreKeys.BoredRequest.activity) as? String,
                        let postedTimestamp = document.get(FirestoreKeys.BoredRequest.postedTime) as? Timestamp,
                        let expiresTimestamp = document.get(FirestoreKeys.BoredRequest.expiresAt) as? Timestamp,
                        let initiatedBy = document.get(FirestoreKeys.BoredRequest.initiatedBy) as? String,
                        let docGroupID = document.get(FirestoreKeys.BoredRequest.groupIdentifier) as? String,
                        let requestID = document.get(FirestoreKeys.BoredRequest.requestIdentifier) as? String
                    else { continue }
                    
                    let request = BoredRequest(
                        groupID: docGroupID,
                        requestID: requestID,
                        activity: activity,
                        postedTime: postedTimestamp.dateValue(),
                        expiresAt: expiresTimestamp.dateValue(),
                        initiatedBy: initiatedBy,
                        people: [BoredRequestUser]()
                    )
                    allRequests.append(request)
                }
            }
        }
        
        group.notify(queue: .main) {
            let deduped = allRequests.filterDuplicates { $0.requestID == $1.requestID }
            completion(.success(deduped))
        }
    }
    
    public func downloadBoredRequestResponses(groupID: String, requestID: String, completion: @escaping (Result<DocumentSnapshot?, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).whereField(FirestoreKeys.BoredRequest.requestIdentifier, isEqualTo: requestID).getDocuments() { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(querySnapshot?.documents.first))
        }
    }
    
    public func updateBoredRequestResponse(groupID: String, requestID: String, uid: String, status: String, substatus: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).document(requestID).setData([
            FirestoreKeys.BoredRequest.availabilityField(forUID: uid) : status,
            FirestoreKeys.BoredRequest.substatusField(forUID: uid) : substatus
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    // MARK: - Friend Groups
    public func loadGroup(groupID: String, completion: @escaping (Result<FriendGroup, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).whereField(FirestoreKeys.Group.groupIdentifier, isEqualTo: groupID).getDocuments { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let document = querySnapshot?.documents.first else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            do {
                let group = try document.data(as: FriendGroup.self)
                completion(.success(group))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func createGroup(name: String, ownerUID uid: String, completion: @escaping (Result<String, Error>) -> Void) {
        let newGroupID = UUID().uuidString
        db.collection(FirestoreKeys.Collection.friendGroups).document(newGroupID).setData([
            FirestoreKeys.Group.groupIdentifier : newGroupID,
            FirestoreKeys.Group.name : name,
            FirestoreKeys.Group.people : [uid]
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(newGroupID))
            }
        })
    }
    
    public func renameGroup(groupID: String, name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).setData([
            FirestoreKeys.Group.name : name
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func addPersonToGroup(groupID: String, uid: String) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).updateData([
            FirestoreKeys.Group.people : FieldValue.arrayUnion([uid])
        ])
    }
    
    public func removePersonFromGroup(groupID: String, uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).updateData([
            FirestoreKeys.Group.people : FieldValue.arrayRemove([uid])
        ], completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    // MARK: - Friend Requests
    public func sendFriendRequest(toUID friendUID: String, fromName name: String, fromUID uid: String, profileImageURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(friendUID).collection(FirestoreKeys.Collection.friendRequests).document(uid).setData([
            FirestoreKeys.FriendRequest.name : name,
            FirestoreKeys.FriendRequest.userIdentifier : uid,
            FirestoreKeys.FriendRequest.profileImageURL : profileImageURL
        ], merge: true, completion: { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }
    
    public func deleteFriendRequest(forUID uid: String, fromUID requesterUID: String) {
        db.collection(FirestoreKeys.Collection.users).document(uid).collection(FirestoreKeys.Collection.friendRequests).document(requesterUID).delete()
    }
    
    public func downloadFriendRequests(uid: String, completion: @escaping (Result<[FriendRequest], Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(uid).collection(FirestoreKeys.Collection.friendRequests).getDocuments { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let requests: [FriendRequest] = documents.compactMap { try? $0.data(as: FriendRequest.self) }
            completion(.success(requests))
        }
    }
    
    public func acceptFriendRequest(myUID: String, myName: String, friendUID: String, friendName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(myUID).collection(FirestoreKeys.Collection.friends).document(friendUID).setData([
            FirestoreKeys.User.name : friendName,
            FirestoreKeys.User.userIdentifier : friendUID
        ], merge: true, completion: { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.db.collection(FirestoreKeys.Collection.users).document(friendUID).collection(FirestoreKeys.Collection.friends).document(myUID).setData([
                FirestoreKeys.User.name : myName,
                FirestoreKeys.User.userIdentifier : myUID
            ], merge: true, completion: { [weak self] error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                self?.deleteFriendRequest(forUID: myUID, fromUID: friendUID)
                completion(.success(()))
            })
        })
    }
    
    // MARK: - Download All Users
    public func downloadAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).getDocuments { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let users: [User] = documents.compactMap { try? $0.data(as: User.self) }
            completion(.success(users))
        }
    }
    
    // MARK: - Download Users In Subcollection
    public func downloadUsersInSubcollection(uid: String, subcollection: String, completion: @escaping (Result<[User], Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(uid).collection(subcollection).getDocuments() { querySnapshot, error in
            if let error = error  {
                Log.database.error("Error loading friends from Firebase: \(error.localizedDescription, privacy: .public)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let users: [User] = documents.compactMap {
                do {
                    return try $0.data(as: User.self)
                } catch {
                    Log.database.error("Error decoding User from Firestore: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            completion(.success(users))
        }
    }
    
    // MARK: - Download All Friends
    public func downloadAllFriends(uid: String, completion: @escaping (Result<[Friend], Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.users).document(uid).collection(FirestoreKeys.Collection.friends).getDocuments() { querySnapshot, error in
            if let error = error  {
                Log.database.error("Error loading friends from Firebase: \(error.localizedDescription, privacy: .public)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let users: [Friend] = documents.compactMap {
                do {
                    return try $0.data(as: Friend.self)
                } catch {
                    Log.database.error("Error decoding Friend from Firestore: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            completion(.success(users))
        }
    }
    
    // MARK: - Download All Groups
    public func downloadAllGroups(uid: String, completion: @escaping (Result<[FriendGroup], Error>) -> Void) {
        db.collection(FirestoreKeys.Collection.friendGroups).whereField(FirestoreKeys.Group.people, arrayContains: uid).getDocuments() { querySnapshot, error in
            guard error == nil else {
                Log.database.error("Error downloading groups from Firestore: \(error!.localizedDescription, privacy: .public)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            var groups: [FriendGroup] = documents.compactMap {
                do {
                    let group = try $0.data(as: FriendGroup.self)
                    return FriendGroup(name: group.name.lowercased(), groupID: group.groupID, people: group.people)
                } catch {
                    Log.database.error("Error decoding FriendGroup from Firestore: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            groups = groups.filterDuplicates { $0.groupID == $1.groupID }
            completion(.success(groups))
        }
    }
    
    // MARK: - Download Friends In Group
    public func downloadFriends(fromGroupWith: [String], completion: @escaping (Result<[Friend], Error>) -> Void) {
        guard !fromGroupWith.isEmpty else {
            completion(.failure(DatabaseError.failedToFetch))
            return
        }
        
        var friendsReturn = [Friend]()
        let group = DispatchGroup()
        
        for memberUID in fromGroupWith {
            group.enter()
            db.collection(FirestoreKeys.Collection.users).whereField(FirestoreKeys.User.userIdentifier, isEqualTo: memberUID).getDocuments() { querySnapshot, error in
                defer { group.leave() }
                
                if let error = error  {
                    Log.database.error("Error loading friends from Firebase: \(error.localizedDescription, privacy: .public)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                for document in documents {
                    do {
                        let friend = try document.data(as: Friend.self)
                        friendsReturn.append(friend)
                    } catch {
                        Log.database.error("Error decoding Friend from Firestore: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if friendsReturn.isEmpty {
                completion(.failure(DatabaseError.failedToFetch))
            } else {
                completion(.success(friendsReturn))
            }
        }
    }
    
    // MARK: - Block User
    // Adds an external user's email to the current user's "Blocked Users" subcollection
    public func blockUser(uidToBlock: String, completion: @escaping (Bool) -> Void) {
        
        // Update local cache of blocked users
        var blockedUsers = SecureStorage.blockedUsers
        blockedUsers.append(uidToBlock)
        SecureStorage.blockedUsers = blockedUsers
        
        // Update Firestore collection of blocked users
        let uid = SecureStorage.uid!
        let date = Date().toString(dateFormat: "yyyy-MM-dd 'at' HH:mm:ss")
        
        db.collection(FirestoreKeys.Collection.blockedUsers).document(uidToBlock).setData([
            FirestoreKeys.BlockedUser.blockingUserIdentifier : uid,
            FirestoreKeys.BlockedUser.blockedUserIdentifier : uidToBlock,
            FirestoreKeys.BlockedUser.blockedOn : date
        ], merge: false, completion: { error in
            guard error == nil else {
                Log.database.error("Error blocking user: \(error!.localizedDescription, privacy: .public)")
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
        SecureStorage.blockedUsers = [""]
        SecureStorage.whoBlockedMe = [""]
        
        var blockedUsers: [String] = [""]
        var whoBlockedMe: [String] = [""]
        var encounteredError = false
        let group = DispatchGroup()
        
        group.enter()
        db.collection(FirestoreKeys.Collection.blockedUsers).whereField(FirestoreKeys.BlockedUser.blockedUserIdentifier, isEqualTo: uid).getDocuments() { (snapshot, error) in
            defer { group.leave() }
            
            guard error == nil else {
                Log.database.error("Error accessing blocked users subcollection: \(error!.localizedDescription, privacy: .public)")
                encounteredError = true
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            for document in documents {
                if let blockedMe = document.get(FirestoreKeys.BlockedUser.blockingUserIdentifier) as? String {
                    whoBlockedMe.append(blockedMe)
                }
            }
        }
        
        group.enter()
        db.collection(FirestoreKeys.Collection.blockedUsers).whereField(FirestoreKeys.BlockedUser.blockingUserIdentifier, isEqualTo: uid).getDocuments() { (snapshot, error) in
            defer { group.leave() }
            
            guard error == nil else {
                Log.database.error("Error accessing blocked users subcollection: \(error!.localizedDescription, privacy: .public)")
                encounteredError = true
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            for document in documents {
                if let blockedYou = document.get(FirestoreKeys.BlockedUser.blockedUserIdentifier) as? String {
                    blockedUsers.append(blockedYou)
                }
            }
        }
        
        group.notify(queue: .main) {
            if encounteredError {
                completion(false)
                return
            }
            SecureStorage.whoBlockedMe = whoBlockedMe
            SecureStorage.blockedUsers = blockedUsers
            completion(true)
        }
    }
}
// MARK: - Async/Await API
// These bridge to the callback-based methods above so the two APIs
// stay in lockstep until callers can fully migrate to async/await.
extension DatabaseManager {
    
    public func downloadUser(where field: String, isEqualTo value: String) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            downloadUser(where: field, isEqualTo: value) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadUsersInSubcollection(uid: String, subcollection: String) async throws -> [User] {
        try await withCheckedThrowingContinuation { continuation in
            downloadUsersInSubcollection(uid: uid, subcollection: subcollection) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadAllFriends(uid: String) async throws -> [Friend] {
        try await withCheckedThrowingContinuation { continuation in
            downloadAllFriends(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadAllGroups(uid: String) async throws -> [FriendGroup] {
        try await withCheckedThrowingContinuation { continuation in
            downloadAllGroups(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadFriends(fromGroupWith people: [String]) async throws -> [Friend] {
        try await withCheckedThrowingContinuation { continuation in
            downloadFriends(fromGroupWith: people) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @discardableResult
    public func blockUser(uidToBlock: String) async -> Bool {
        await withCheckedContinuation { continuation in
            blockUser(uidToBlock: uidToBlock) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    @discardableResult
    public func updateBlockedUsersList(uid: String) async -> Bool {
        await withCheckedContinuation { continuation in
            updateBlockedUsersList(uid: uid) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    public func createUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            createUser(user) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func updateUserName(uid: String, name: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            updateUserName(uid: uid, name: name) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func updateUserStatus(uid: String, status: String, substatus: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            updateUserStatus(uid: uid, status: status, substatus: substatus) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func softDeleteUserProfile(uid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            softDeleteUserProfile(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func softDeleteFriendReferences(toUID uid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            softDeleteFriendReferences(toUID: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadAllUsers() async throws -> [User] {
        try await withCheckedThrowingContinuation { continuation in
            downloadAllUsers { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func sendFriendRequest(toUID friendUID: String, fromName name: String, fromUID uid: String, profileImageURL: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sendFriendRequest(toUID: friendUID, fromName: name, fromUID: uid, profileImageURL: profileImageURL) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadFriendRequests(uid: String) async throws -> [FriendRequest] {
        try await withCheckedThrowingContinuation { continuation in
            downloadFriendRequests(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func acceptFriendRequest(myUID: String, myName: String, friendUID: String, friendName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            acceptFriendRequest(myUID: myUID, myName: myName, friendUID: friendUID, friendName: friendName) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func loadGroup(groupID: String) async throws -> FriendGroup {
        try await withCheckedThrowingContinuation { continuation in
            loadGroup(groupID: groupID) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func createGroup(name: String, ownerUID: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            createGroup(name: name, ownerUID: ownerUID) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func renameGroup(groupID: String, name: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            renameGroup(groupID: groupID, name: name) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func removePersonFromGroup(groupID: String, uid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            removePersonFromGroup(groupID: groupID, uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func createBoredRequest(requestID: String, groupID: String, initiatedBy: String, postedTime: Date, expiresAt: Date, activity: String, initiatorUID: String, initiatorSubstatus: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            createBoredRequest(requestID: requestID, groupID: groupID, initiatedBy: initiatedBy, postedTime: postedTime, expiresAt: expiresAt, activity: activity, initiatorUID: initiatorUID, initiatorSubstatus: initiatorSubstatus) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadBoredRequests(forGroupIDs groupIDs: [String], notExpiredSince expiredCutoff: Timestamp) async throws -> [BoredRequest] {
        try await withCheckedThrowingContinuation { continuation in
            downloadBoredRequests(forGroupIDs: groupIDs, notExpiredSince: expiredCutoff) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func updateBoredRequestResponse(groupID: String, requestID: String, uid: String, status: String, substatus: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            updateBoredRequestResponse(groupID: groupID, requestID: requestID, uid: uid, status: status, substatus: substatus) { result in
                continuation.resume(with: result)
            }
        }
    }
}

