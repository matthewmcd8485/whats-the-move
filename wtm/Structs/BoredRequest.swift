//
//  BoredRequest.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/2/21.
//

import Foundation

struct BoredRequest {
    let groupID: String
    let requestID: String
    let activity: String
    let postedTime: Date
    /// Not fixed at send time: the sender can end a request early or push it
    /// back, so this moves after the fact.
    var expiresAt: Date
    let initiatedBy: String
    /// The sender's uid. `nil` on requests written before the field existed;
    /// see `isMine` for what stands in for it.
    let initiatorUID: String?
    var people: [BoredRequestUser]
    
    init(groupID: String, requestID: String, activity: String, postedTime: Date, expiresAt: Date, initiatedBy: String, initiatorUID: String? = nil, people: [BoredRequestUser]) {
        self.groupID = groupID
        self.requestID = requestID
        self.activity = activity
        self.postedTime = postedTime
        self.expiresAt = expiresAt
        self.initiatedBy = initiatedBy
        self.initiatorUID = initiatorUID
        self.people = people
    }
    
    init() {
        groupID = ""
        requestID = ""
        activity = ""
        postedTime = Date()
        expiresAt = Date()
        initiatedBy = ""
        initiatorUID = nil
        people = [BoredRequestUser]()
    }
    
    /// Whether you're the one who sent this — which is what decides who may
    /// expire it, and which way round a direct request reads.
    ///
    /// The recorded uid answers it outright. Requests written before that field
    /// existed hold only the sender's *name*, so those fall back to comparing
    /// names: inside a group that also matches anyone who shares a name with
    /// the sender, which is why it's the fallback rather than the answer.
    var isMine: Bool {
        if let initiatorUID {
            return initiatorUID == SecureStorage.uid
        }
        let myName = UserDefaults.standard.string(forKey: "name") ?? ""
        return !myName.isEmpty
            && initiatedBy.caseInsensitiveCompare(myName) == .orderedSame
    }
    
    /// Whether this request has run out of time. The list filters on it, so a
    /// request whose expiry has been pulled forward drops off everyone's.
    var hasExpired: Bool { expiresAt <= Date() }
}
