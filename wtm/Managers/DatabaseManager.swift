//
//  DatabaseManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

// `@unchecked` because the only stored property is a Firestore client, which
// Firebase documents as thread-safe but does not annotate as Sendable. There is
// no other mutable state on this type.
final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    let db = Firestore.firestore()
    /// Used for lookups the client isn't allowed to make itself — matching
    /// phone numbers against accounts, which would otherwise mean enumerating
    /// the whole `users` collection.
    private let functions = Functions.functions()
    
    // MARK: - Download User
    /// One account, by uid.
    ///
    /// A direct document read rather than a query on the `User Identifier`
    /// field, whose value is the document's own id — `createUser` writes every
    /// account at `users/{uid}`, and the push fan-out has always resolved
    /// recipients with `.doc(uid)`, so the two being the same is already
    /// load-bearing in production. Reading by id needs no index, can't return
    /// two documents, and is served from Firestore's offline cache far more
    /// readily than a query is.
    ///
    /// It's also the only way left to read somebody else's profile: the
    /// security rules now deny `list` on `users`, so queries over that
    /// collection fail outright.
    public func downloadUser(uid: String) async throws -> User {
        let document: DocumentSnapshot
        do {
            document = try await db
                .collection(FirestoreKeys.Collection.users)
                .document(uid)
                .getDocument()
        } catch {
            Log.database.error("Error loading user from Firebase: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.failedToFetch
        }

        guard document.exists else { throw DatabaseError.failedToFetch }

        do {
            return try document.data(as: User.self)
        } catch {
            Log.database.error("Error decoding User from Firestore: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.failedToFetch
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
            FirestoreKeys.User.phoneKey : FirestoreKeys.User.phoneKey(from: user.phoneNumber),
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
            // Blanked rather than marked, so a deleted account stops matching
            // anyone's address book. Writing the marker here would have made
            // every deleted account collide on one key.
            FirestoreKeys.User.phoneKey : "",
            FirestoreKeys.User.profileImageURL : deletedMarker,
            // `Joined` is deliberately left alone. It's a date, and stamping
            // prose into it made the field hold two different kinds of value
            // depending on whether the account was alive.
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
    //
    // Requests are a top-level collection. They used to be a subcollection of
    // the group they belonged to, which meant the only way to ask "what's open
    // for me" was to ask each group separately — and because every 1:1 request
    // synthesizes a permanent two-person "direct" group, the number of groups
    // to ask grew by one for each friend ever pinged. A `Recipients` array on
    // the request replaces all of that with one query.

    /// The document for a request, wherever it lives.
    private func boredRequestRef(_ requestID: String) -> DocumentReference {
        db.collection(FirestoreKeys.Collection.boredRequests).document(requestID)
    }

    public func createBoredRequest(requestID: String, groupID: String, recipients: [String], initiatedBy: String, postedTime: Date, expiresAt: Date, activity: String, initiatorUID uid: String, initiatorSubstatus substatus: String, timeSensitive: Bool, imageURL: String) async throws {
        // The sender is a recipient too: it's their own list the request has to
        // appear in, and the push fan-out excludes them separately.
        let audience = Array(Set(recipients).union([uid]))

        try await boredRequestRef(requestID).setData([
            FirestoreKeys.BoredRequest.requestIdentifier : requestID,
            FirestoreKeys.BoredRequest.initiatedBy : initiatedBy,
            FirestoreKeys.BoredRequest.initiatorIdentifier : uid,
            FirestoreKeys.BoredRequest.recipients : audience,
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

    /// Every request addressed to this person that hasn't expired yet.
    ///
    /// Filtered on expiry rather than posted time. Requests used to get a flat
    /// two hours, so "posted within two hours" was the same question; now that
    /// the sender picks the length and can extend it afterwards, a request's
    /// age says nothing about whether it's still open.
    public func downloadBoredRequests(forUID uid: String, expiringAfter cutoff: Timestamp) async throws -> [BoredRequest] {
        let snapshot: QuerySnapshot
        do {
            snapshot = try await db
                .collection(FirestoreKeys.Collection.boredRequests)
                .whereField(FirestoreKeys.BoredRequest.recipients, arrayContains: uid)
                .whereField(FirestoreKeys.BoredRequest.expiresAt, isGreaterThan: cutoff)
                .getDocuments()
        } catch {
            Log.database.error("error loading bored requests: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.failedToFetch
        }

        return snapshot.documents.compactMap { document in
            guard
                let activity = document.get(FirestoreKeys.BoredRequest.activity) as? String,
                let postedTimestamp = document.get(FirestoreKeys.BoredRequest.postedTime) as? Timestamp,
                let expiresTimestamp = document.get(FirestoreKeys.BoredRequest.expiresAt) as? Timestamp,
                let initiatedBy = document.get(FirestoreKeys.BoredRequest.initiatedBy) as? String,
                let docGroupID = document.get(FirestoreKeys.BoredRequest.groupIdentifier) as? String,
                let requestID = document.get(FirestoreKeys.BoredRequest.requestIdentifier) as? String
            else { return nil }

            return BoredRequest(
                groupID: docGroupID,
                requestID: requestID,
                activity: activity,
                postedTime: postedTimestamp.dateValue(),
                expiresAt: expiresTimestamp.dateValue(),
                initiatedBy: initiatedBy,
                initiatorUID: document.get(FirestoreKeys.BoredRequest.initiatorIdentifier) as? String,
                people: [BoredRequestUser]()
            )
        }
        .filterDuplicates { $0.requestID == $1.requestID }
    }

    /// The response fields recorded on a request, keyed by uid.
    ///
    /// A direct document read; this was a query on `Request Identifier`, whose
    /// value is the document's own id.
    public func downloadBoredRequestResponses(requestID: String) async throws -> [String: Any] {
        let document = try await boredRequestRef(requestID).getDocument()
        guard document.exists, let data = document.data() else {
            throw DatabaseError.failedToFetch
        }
        return data
    }

    /// Moves when a request expires — forward to now to end it, or back to
    /// give it longer.
    ///
    /// Merged rather than deleted even when ending it: the responses already
    /// given live on the same document, and a delete would make it vanish from
    /// under anyone who has the request open. Everyone's list filters on
    /// expiry, so moving the date is enough to take it off theirs too.
    public func setBoredRequestExpiry(requestID: String, to expiresAt: Date) async throws {
        try await boredRequestRef(requestID)
            .setData([FirestoreKeys.BoredRequest.expiresAt : expiresAt], merge: true)
    }

    public func updateBoredRequestResponse(requestID: String, uid: String, status: String, substatus: String) async throws {
        try await boredRequestRef(requestID).setData([
            FirestoreKeys.BoredRequest.availabilityField(forUID: uid) : status,
            FirestoreKeys.BoredRequest.substatusField(forUID: uid) : substatus
        ], merge: true)
    }
    
    // MARK: - Friend Groups
    /// One group, by id.
    ///
    /// A direct document read; this was a query on `Group Identifier`, whose
    /// value is the document's own id. `createGroup` and `ensureDirectGroup`
    /// both write at `friend groups/{groupID}`, and the push fan-out has always
    /// read them back with `.doc(groupId)`.
    public func loadGroup(groupID: String) async throws -> FriendGroup {
        let document = try await db
            .collection(FirestoreKeys.Collection.friendGroups)
            .document(groupID)
            .getDocument()

        guard document.exists else { throw DatabaseError.failedToFetch }
        return try document.data(as: FriendGroup.self)
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

    // MARK: - Find Users By Phone Number
    /// An account matched to one of the phone numbers asked about.
    struct PhoneMatch: Decodable {
        /// The normalized key this account matched on, so the caller can pair
        /// it back to the contact it sent.
        let phoneKey: String
        let profile: User
    }

    /// Looks up accounts by phone number through the `findUsersByPhone`
    /// function.
    ///
    /// This replaces `downloadAllUsers`, which pulled the entire `users`
    /// collection to the device so the contact importer could match against it
    /// locally — a read of every account in the database, every import — and a
    /// client-side query for the single-number search on the add-friend
    /// screen. Both are now impossible anyway: the rules deny `list` on
    /// `users`. The function returns only the accounts that matched, with the
    /// `FCM Token` field blanked out.
    ///
    /// Accepts numbers in any format; normalization to the last 10 digits
    /// happens on both sides.
    public func findUsers(phoneNumbers: [String]) async throws -> [PhoneMatch] {
        guard !phoneNumbers.isEmpty else { return [] }

        let response = try await functions
            .httpsCallable("findUsersByPhone")
            .call(["phoneNumbers": phoneNumbers])

        // The callable hands back `{ matches: [...] }` as untyped JSON, so it
        // makes the round trip through JSONSerialization to reach `Decodable`.
        guard let payload = response.data as? [String: Any],
              let matches = payload["matches"] else {
            throw DatabaseError.failedToFetch
        }

        let data = try JSONSerialization.data(withJSONObject: matches)
        return try JSONDecoder().decode([PhoneMatch].self, from: data)
    }

    /// A single account by phone number, for the add-friend search.
    public func findUser(phoneNumber: String) async throws -> User {
        guard let match = try await findUsers(phoneNumbers: [phoneNumber]).first else {
            throw DatabaseError.failedToFetch
        }
        return match.profile
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
    
    // MARK: - Download Users By UID
    /// The user documents for `uids`, read concurrently and de-duplicated.
    ///
    /// Reads by document id rather than with a `whereField(... in:)` batch.
    /// Batching would mean fewer round trips, but it's a *query*, and the
    /// security rules deny `list` on `users` — that denial is what stops the
    /// whole user base being enumerable. Firestore bills a query by the
    /// documents it returns, so 30 gets and one 30-value `in` query cost the
    /// same number of reads; only the round-trip count differs, and the SDK
    /// multiplexes these over one connection. Reading by id is also served
    /// from the offline cache more readily than a query is.
    ///
    /// Returns the raw snapshots so callers decode into whichever of `Friend`
    /// or `User` they need — `User` requires far more fields to be present, so
    /// a caller that only wants a name and a uid shouldn't have to risk a
    /// sparse legacy document failing to decode.
    private func userDocuments(forUIDs uids: [String]) async -> [DocumentSnapshot] {
        let unique = Array(Set(uids))
        guard !unique.isEmpty else { return [] }

        return await withTaskGroup(of: DocumentSnapshot?.self) { group in
            for uid in unique {
                group.addTask {
                    do {
                        let document = try await self.db
                            .collection(FirestoreKeys.Collection.users)
                            .document(uid)
                            .getDocument()
                        return document.exists ? document : nil
                    } catch {
                        Log.database.error("Error loading user from Firebase: \(error.localizedDescription, privacy: .public)")
                        return nil
                    }
                }
            }

            var collected = [DocumentSnapshot]()
            for await document in group {
                if let document { collected.append(document) }
            }
            return collected
        }
    }

    /// Full profiles for the given uids, fetched concurrently.
    public func downloadUsers(uids: [String]) async -> [User] {
        guard !uids.isEmpty else { return [] }
        return await userDocuments(forUIDs: uids).compactMap { document in
            do {
                return try document.data(as: User.self)
            } catch {
                Log.database.error("Error decoding User from Firestore: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        .filterDuplicates { $0.uid == $1.uid }
    }

    // MARK: - Download Friends In Group
    // Shares the concurrent by-id read above, which replaced a per-uid query
    // fan-out. The saving isn't the read count — that's per document either
    // way — it's that this no longer needs an index, no longer risks two
    // documents coming back for one person, and de-duplicates once.
    public func downloadFriends(fromGroupWith people: [String]) async throws -> [Friend] {
        guard !people.isEmpty else { throw DatabaseError.failedToFetch }

        let friends = await userDocuments(forUIDs: people).compactMap { document in
            do {
                return try document.data(as: Friend.self)
            } catch {
                Log.database.error("Error decoding Friend from Firestore: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        .filterDuplicates { $0.uid == $1.uid }

        guard !friends.isEmpty else { throw DatabaseError.failedToFetch }
        return friends
    }
    
    // MARK: - Block User
    // Records that the current user has blocked someone, in the top-level
    // "blocked users" collection.
    //
    // The document is keyed on *both* uids. Keying it on the blocked user
    // alone meant a block identified only who was blocked, not who blocked
    // them — so the second person to block someone overwrote the first
    // person's document and silently un-blocked them. The pair is also the
    // natural key: blocking the same person twice now lands on the same
    // document instead of relying on `merge: false` to overwrite it.
    //
    // Reads go through `blockedIdentifiers`, which filters on the uid fields
    // rather than the document ID, so documents written under the old scheme
    // keep working and need no migration.
    public func blockUser(uidToBlock: String, completion: @escaping (Bool) -> Void) {
        guard let uid = SecureStorage.uid else {
            Log.database.error("Error blocking user: no signed-in uid")
            completion(false)
            return
        }

        // Update local cache of blocked users
        var blockedUsers = SecureStorage.blockedUsers
        if !blockedUsers.contains(uidToBlock) {
            blockedUsers.append(uidToBlock)
            SecureStorage.blockedUsers = blockedUsers
        }

        db.collection(FirestoreKeys.Collection.blockedUsers).document("\(uid)_\(uidToBlock)").setData([
            FirestoreKeys.BlockedUser.blockingUserIdentifier : uid,
            FirestoreKeys.BlockedUser.blockedUserIdentifier : uidToBlock,
            // A real timestamp rather than a preformatted string, which was
            // neither sortable nor comparable.
            FirestoreKeys.BlockedUser.blockedOn : Date()
        ], merge: true, completion: { error in
            guard error == nil else {
                Log.database.error("Error blocking user: \(error!.localizedDescription, privacy: .public)")
                completion(false)
                return
            }
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
    
    @discardableResult
    public func blockUser(uidToBlock: String) async -> Bool {
        await withCheckedContinuation { continuation in
            blockUser(uidToBlock: uidToBlock) { success in
                continuation.resume(returning: success)
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
    
}

