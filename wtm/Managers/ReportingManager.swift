//
//  ReportingManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//

import Foundation
import FirebaseFirestore

// `@unchecked` because the only stored property is a Firestore client, which is
// thread-safe but not annotated as Sendable. The blocked-user lists this reads
// live in the Keychain, not in instance state.
final class ReportingManager: @unchecked Sendable {

    static let shared = ReportingManager()

    let firestore = Firestore.firestore()
    
    // Checks a cached array to see if a particular user is blocked
    public func userIsBlocked(theirUID: String) -> Bool {
        let blockedUsers = SecureStorage.blockedUsers
        
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
        let whoBlockedMe = SecureStorage.whoBlockedMe
        
        guard !whoBlockedMe.isEmpty else {
            return false
        }
        
        if let blockedUser = whoBlockedMe.first(where: { $0 == theirUID }) {
            print("\(blockedUser) blocked you; removing them from results.")
            return true
        }
        
        return false
    }
    
    // Files a report against another account.
    //
    // Auto-assigned document id, and the reporter is recorded. The id used to
    // be `{reportedUID}_{date}` with no note of who filed it, which meant a
    // report couldn't be attributed — there was no way to tell one person
    // reporting someone from ten people reporting them — and nothing stopped
    // an account filing reports in someone else's name. The security rules now
    // require the reporter field to match the caller.
    public func reportUser(uid: String, name: String, date: String) async -> Bool {
        guard let myUID = SecureStorage.uid else {
            Log.database.error("Error reporting user: no signed-in uid")
            return false
        }

        do {
            try await firestore
                .collection(FirestoreKeys.Collection.reportedUsers)
                .addDocument(data: [
                    FirestoreKeys.ReportedUser.userIdentifier : uid,
                    FirestoreKeys.ReportedUser.reportingUserIdentifier : myUID,
                    FirestoreKeys.ReportedUser.reportedDate : date,
                    FirestoreKeys.ReportedUser.userName : name
                ])
            return true
        } catch {
            Log.database.error("Error reporting user: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
