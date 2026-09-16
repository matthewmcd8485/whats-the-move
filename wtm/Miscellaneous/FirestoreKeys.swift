//
//  FirestoreKeys.swift
//  wtm?
//
//  Single source of truth for Firestore collection and field names.
//

import Foundation

enum FirestoreKeys {
    
    enum Collection {
        static let users = "users"
        static let friends = "friends"
        static let friendRequests = "friend requests"
        static let friendGroups = "friend groups"
        static let boredRequests = "bored requests"
        static let blockedUsers = "blocked users"
        static let reportedUsers = "reported users"
    }
    
    enum User {
        static let name = "Name"
        static let phoneNumber = "Phone Number"
        static let userIdentifier = "User Identifier"
        static let fcmToken = "FCM Token"
        static let status = "Status"
        static let substatus = "Substatus"
        static let profileImageURL = "Profile Image URL"
        static let joined = "Joined"
        static let explicit = "Explicit"
    }
    
    enum Group {
        static let name = "Name"
        static let groupIdentifier = "Group Identifier"
        static let people = "People"
        static let direct = "Direct"
    }
    
    enum FriendRequest {
        static let name = "Name"
        static let userIdentifier = "User Identifier"
        static let profileImageURL = "Profile Image URL"
    }
    
    enum BoredRequest {
        static let requestIdentifier = "Request Identifier"
        static let groupIdentifier = "Group Identifier"
        static let initiatedBy = "Initiated By"
        /// The sender's uid. Only their *name* used to be recorded, which
        /// can't tell whose request it is when two people in a group share a
        /// name. Absent on requests written by builds before this existed.
        static let initiatorIdentifier = "Initiator Identifier"
        static let postedTime = "Posted Time"
        static let expiresAt = "Expires At"
        static let activity = "Activity"
        static let timeSensitive = "Time Sensitive"
        /// Download URL for the activity artwork, so the push fan-out can
        /// attach it without having to resolve Storage itself.
        static let imageURL = "Image URL"
        
        static func availabilityField(forUID uid: String) -> String { "\(uid) Availability" }
        static func substatusField(forUID uid: String) -> String { "\(uid) Substatus" }
    }
    
    enum BlockedUser {
        static let blockingUserIdentifier = "Blocking User's Identifier"
        static let blockedUserIdentifier = "Blocked User's Identifier"
        static let blockedOn = "Blocked On"
    }
    
    enum ReportedUser {
        static let userIdentifier = "User Identifier"
        static let userName = "User Name"
        static let reportedDate = "Reported Date"
    }
}
