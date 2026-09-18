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
        /// Last 10 digits of the phone number — the part that identifies a
        /// subscriber however the country code was written.
        ///
        /// Stored alongside the number so the `findUsersByPhone` function can
        /// match contacts with a query. Matching used to happen on the device,
        /// against every account in the database.
        static let phoneKey = "Phone Key"
        static let userIdentifier = "User Identifier"
        static let fcmToken = "FCM Token"
        static let status = "Status"
        static let substatus = "Substatus"
        static let profileImageURL = "Profile Image URL"
        static let joined = "Joined"
        static let explicit = "Explicit"

        /// Last 10 digits of `raw`. Mirrors `phoneKey` in `functions/index.js`;
        /// the two have to agree or contact matching silently finds nothing.
        static func phoneKey(from raw: String) -> String {
            String(raw.filter(\.isNumber).suffix(10))
        }
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
        /// Everyone the request went to, the sender included.
        ///
        /// Requests are a top-level collection now, so this array is what
        /// makes "every open request for me" a single `arrayContains` query.
        /// Nested under a group, the same question needed one query per group
        /// — and the direct groups that back 1:1 requests accumulate one per
        /// friend you've ever pinged, so that count only ever grew.
        ///
        /// Frozen at send time: someone added to the group afterwards wasn't
        /// invited to this request and shouldn't see it appear late.
        static let recipients = "Recipients"
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
        /// Who filed the report. A report used to record only who it was
        /// against, which left no way to tell one person reporting someone
        /// from ten people reporting them — and no way for the rules to stop
        /// an account filing reports in someone else's name.
        static let reportingUserIdentifier = "Reporting User Identifier"
    }
}
