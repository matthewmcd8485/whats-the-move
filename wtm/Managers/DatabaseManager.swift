//
//  DatabaseManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import Foundation
import FirebaseFirestore

// `@unchecked` because the only stored property is a Firestore client, which
// Firebase documents as thread-safe but does not annotate as Sendable. There is
// no other mutable state on this type.
final class DatabaseManager: @unchecked Sendable {
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
    public func createUser(_ user: User) async throws {
        try await db.collection(FirestoreKeys.Collection.users).document(user.uid).setData([
            FirestoreKeys.User.name : user.name,
            FirestoreKeys.User.phoneNumber : user.phoneNumber,
            FirestoreKeys.User.userIdentifier : user.uid,
            FirestoreKeys.User.fcmToken : user.fcmToken,
            FirestoreKeys.User.status : user.status,
            FirestoreKeys.User.substatus : user.substatus,
            FirestoreKeys.User.joined : user.joinedTime,
            FirestoreKeys.User.profileImageURL : user.profileImageURL,
            FirestoreKeys.User.explicit : user.explicit
        ], merge: true)
    }

    public func updateUserExplicit(uid: String, enabled: Bool) async throws {
        try await db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.explicit : enabled
        ], merge: true)
    }
    
    public func updateUserName(uid: String, name: String) async throws {
        try await db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.name : name
        ], merge: true)
    }
    
    public func updateUserStatus(uid: String, status: String, substatus: String) async throws {
        try await db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.status : status,
            FirestoreKeys.User.substatus : substatus
        ], merge: true)
    }
    
    public func updateUserProfileImageURL(uid: String, url: String) {
        db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.profileImageURL : url
        ], merge: true)
    }
    
    // MARK: - Soft-delete User
    public func softDeleteUserProfile(uid: String) async throws {
        let deletedMarker = "user deleted"
        try await db.collection(FirestoreKeys.Collection.users).document(uid).setData([
            FirestoreKeys.User.name : deletedMarker,
            FirestoreKeys.User.phoneNumber : deletedMarker,
            FirestoreKeys.User.profileImageURL : deletedMarker,
            FirestoreKeys.User.joined : deletedMarker,
            FirestoreKeys.User.fcmToken : deletedMarker,
            FirestoreKeys.User.status : deletedMarker,
            FirestoreKeys.User.substatus : deletedMarker
        ], merge: true)
    }

    // Awaits each rename rather than firing them off unawaited, so a caller
    // that returns successfully knows the references are actually updated.
    public func softDeleteFriendReferences(toUID uid: String) async throws {
        let snapshot = try await db
            .collectionGroup(FirestoreKeys.Collection.friends)
            .whereField(FirestoreKeys.User.userIdentifier, isEqualTo: uid)
            .getDocuments()

        for document in snapshot.documents {
            try await document.reference.setData([
                FirestoreKeys.User.name : "user deleted"
            ], merge: true)
        }
    }
    
    // MARK: - Bored Requests
    public func createBoredRequest(requestID: String, groupID: String, initiatedBy: String, postedTime: Date, expiresAt: Date, activity: String, initiatorUID uid: String, initiatorSubstatus substatus: String, timeSensitive: Bool, imageURL: String) async throws {
        try await db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).document(requestID).setData([
            FirestoreKeys.BoredRequest.requestIdentifier : requestID,
            FirestoreKeys.BoredRequest.initiatedBy : initiatedBy,
            FirestoreKeys.BoredRequest.initiatorIdentifier : uid,
            FirestoreKeys.BoredRequest.postedTime : postedTime,
            FirestoreKeys.BoredRequest.expiresAt : expiresAt,
            FirestoreKeys.BoredRequest.activity : activity,
            FirestoreKeys.BoredRequest.groupIdentifier : groupID,
            FirestoreKeys.BoredRequest.timeSensitive : timeSensitive,
            FirestoreKeys.BoredRequest.imageURL : imageURL,
            FirestoreKeys.BoredRequest.availabilityField(forUID: uid) : "available",
            FirestoreKeys.BoredRequest.substatusField(forUID: uid) : substatus
        ], merge: false)
    }
    
    /// Every request in the given groups that hasn't expired yet.
    ///
    /// Filtered on expiry rather than posted time. Requests used to get a flat
    /// two hours, so "posted within two hours" was the same question; now that
    /// the sender picks the length and can extend it afterwards, a request's
    /// age says nothing about whether it's still open.
    public func downloadBoredRequests(forGroupIDs groupIDs: [String], expiringAfter cutoff: Timestamp, completion: @escaping (Result<[BoredRequest], Error>) -> Void) {
        guard !groupIDs.isEmpty else {
            completion(.success([]))
            return
        }
        
        var allRequests = [BoredRequest]()
        let group = DispatchGroup()
        
        for groupID in groupIDs {
            group.enter()
            db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).collection(FirestoreKeys.Collection.boredRequests).whereField(FirestoreKeys.BoredRequest.expiresAt, isGreaterThan: cutoff).getDocuments() { querySnapshot, error in
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
                        // Optional, unlike the rest: requests written before
                        // this field existed are still perfectly readable.
                        initiatorUID: document.get(FirestoreKeys.BoredRequest.initiatorIdentifier) as? String,
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
    
    /// Moves when a request expires — forward to now to end it, or back to
    /// give it longer.
    ///
    /// Merged rather than deleted even when ending it: the responses already
    /// given live on the same document, and a delete would make it vanish from
    /// under anyone who has the request open. Everyone's list filters on
    /// expiry, so moving the date is enough to take it off theirs too.
    public func setBoredRequestExpiry(groupID: String, requestID: String, to expiresAt: Date) async throws {
        try await db.collection(FirestoreKeys.Collection.friendGroups)
            .document(groupID)
            .collection(FirestoreKeys.Collection.boredRequests)
            .document(requestID)
            .setData([FirestoreKeys.BoredRequest.expiresAt : expiresAt], merge: true)
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

    // Synthesizes a deterministic two-person "direct" friend group used to back
    // 1:1 bored requests. The ID is derived from the sorted UID pair so repeat
    // sends between the same two users reuse the same group (and thus share a
    // response thread). Marked with `Direct: true` so it can be filtered out of
    // the visible groups list.
    public func directGroupID(uidA: String, uidB: String) -> String {
        let sorted = [uidA, uidB].sorted()
        return "direct-\(sorted[0])-\(sorted[1])"
    }

    public func ensureDirectGroup(myUID: String, friendUID: String) async throws -> String {
        let groupID = directGroupID(uidA: myUID, uidB: friendUID)
        let ref = db.collection(FirestoreKeys.Collection.friendGroups).document(groupID)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData([
                FirestoreKeys.Group.groupIdentifier : groupID,
                FirestoreKeys.Group.name : "direct",
                FirestoreKeys.Group.people : [myUID, friendUID],
                FirestoreKeys.Group.direct : true
            ], merge: true, completion: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
        return groupID
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
    
    /// Ends a friendship from both sides.
    ///
    /// `acceptFriendRequest` writes a document into *each* person's `friends`
    /// subcollection, so deleting only your own copy would leave you still on
    /// their list — and still a valid recipient for their bored requests.
    ///
    /// Groups the two of you share are deliberately left alone, which is how
    /// blocking already behaves.
    public func removeFriend(myUID: String, friendUID: String) async throws {
        let users = db.collection(FirestoreKeys.Collection.users)

        try await users.document(myUID)
            .collection(FirestoreKeys.Collection.friends)
            .document(friendUID)
            .delete()

        try await users.document(friendUID)
            .collection(FirestoreKeys.Collection.friends)
            .document(myUID)
            .delete()
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
    // MARK: - Download All Friends
    public func downloadAllFriends(uid: String) async throws -> [Friend] {
        do {
            let snapshot = try await db
                .collection(FirestoreKeys.Collection.users)
                .document(uid)
                .collection(FirestoreKeys.Collection.friends)
                .getDocuments()
            return snapshot.documents.compactMap { document in
                do {
                    return try document.data(as: Friend.self)
                } catch {
                    Log.database.error("Error decoding Friend from Firestore: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
        } catch {
            Log.database.error("Error loading friends from Firebase: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.failedToFetch
        }
    }

    // MARK: - Download All Groups
    public func downloadAllGroups(uid: String) async throws -> [FriendGroup] {
        do {
            let snapshot = try await db
                .collection(FirestoreKeys.Collection.friendGroups)
                .whereField(FirestoreKeys.Group.people, arrayContains: uid)
                .getDocuments()
            let groups: [FriendGroup] = snapshot.documents.compactMap { document in
                do {
                    let group = try document.data(as: FriendGroup.self)
                    // Rebuilt only to lowercase the name, so `isDirect` has to
                    // be carried over: dropping it made every direct group look
                    // like an ordinary one, which showed its placeholder name
                    // ("direct") instead of the person on the other end.
                    return FriendGroup(
                        name: group.name.lowercased(),
                        groupID: group.groupID,
                        people: group.people,
                        isDirect: group.isDirect
                    )
                } catch {
                    Log.database.error("Error decoding FriendGroup from Firestore: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            return groups.filterDuplicates { $0.groupID == $1.groupID }
        } catch {
            Log.database.error("Error downloading groups from Firestore: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.failedToFetch
        }
    }
    
    // MARK: - Download Friends In Group
    // Fans out one query per member and collects the results. A task group
    // replaces the previous DispatchGroup + shared mutable array, which was a
    // genuine data race: several Firestore callbacks appended to `friendsReturn`
    // concurrently with no synchronization.
    public func downloadFriends(fromGroupWith people: [String]) async throws -> [Friend] {
        guard !people.isEmpty else { throw DatabaseError.failedToFetch }

        let friends = await withTaskGroup(of: [Friend].self) { group in
            for memberUID in people {
                group.addTask {
                    do {
                        let snapshot = try await self.db
                            .collection(FirestoreKeys.Collection.users)
                            .whereField(FirestoreKeys.User.userIdentifier, isEqualTo: memberUID)
                            .getDocuments()
                        return snapshot.documents.compactMap { document in
                            do {
                                return try document.data(as: Friend.self)
                            } catch {
                                Log.database.error("Error decoding Friend from Firestore: \(error.localizedDescription, privacy: .public)")
                                return nil
                            }
                        }
                    } catch {
                        Log.database.error("Error loading friends from Firebase: \(error.localizedDescription, privacy: .public)")
                        return []
                    }
                }
            }

            var collected = [Friend]()
            for await batch in group {
                collected.append(contentsOf: batch)
            }
            return collected
        }

        guard !friends.isEmpty else { throw DatabaseError.failedToFetch }
        return friends
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
    // Refreshes the cached block lists. Returns false if either query failed.
    //
    // The previous version cleared both cached lists up front and only wrote
    // the new values on success, so a failed refresh left them empty — briefly
    // un-blocking everyone. The caches are now only touched once both queries
    // have come back.
    public func updateBlockedUsersList(uid: String) async -> Bool {
        async let iBlocked = blockedIdentifiers(
            matching: FirestoreKeys.BlockedUser.blockingUserIdentifier,
            equalTo: uid,
            reading: FirestoreKeys.BlockedUser.blockedUserIdentifier
        )
        async let blockedMe = blockedIdentifiers(
            matching: FirestoreKeys.BlockedUser.blockedUserIdentifier,
            equalTo: uid,
            reading: FirestoreKeys.BlockedUser.blockingUserIdentifier
        )

        guard let iBlocked = await iBlocked, let blockedMe = await blockedMe else {
            return false
        }

        SecureStorage.blockedUsers = iBlocked
        SecureStorage.whoBlockedMe = blockedMe
        return true
    }

    /// Returns nil on failure so the caller can tell "no one" apart from
    /// "couldn't check".
    private func blockedIdentifiers(
        matching field: String,
        equalTo uid: String,
        reading resultField: String
    ) async -> [String]? {
        do {
            let snapshot = try await db
                .collection(FirestoreKeys.Collection.blockedUsers)
                .whereField(field, isEqualTo: uid)
                .getDocuments()
            return snapshot.documents.compactMap { $0.get(resultField) as? String }
        } catch {
            Log.database.error("Error accessing blocked users subcollection: \(error.localizedDescription, privacy: .public)")
            return nil
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
    
    @discardableResult
    public func blockUser(uidToBlock: String) async -> Bool {
        await withCheckedContinuation { continuation in
            blockUser(uidToBlock: uidToBlock) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    @discardableResult
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
    
    /// Adds several people at once. `arrayUnion` already de-duplicates, so this
    /// is a single write regardless of how many were picked.
    public func addPeopleToGroup(groupID: String, uids: [String]) async throws {
        guard !uids.isEmpty else { return }
        try await db.collection(FirestoreKeys.Collection.friendGroups).document(groupID).updateData([
            FirestoreKeys.Group.people : FieldValue.arrayUnion(uids)
        ])
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
    
    public func downloadBoredRequests(forGroupIDs groupIDs: [String], expiringAfter cutoff: Timestamp) async throws -> [BoredRequest] {
        try await withCheckedThrowingContinuation { continuation in
            downloadBoredRequests(forGroupIDs: groupIDs, expiringAfter: cutoff) { result in
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

