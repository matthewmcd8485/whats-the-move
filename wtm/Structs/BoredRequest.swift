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
    let expiresAt: Date
    let initiatedBy: String
    var people: [BoredRequestUser]
    
    init(groupID: String, requestID: String, activity: String, postedTime: Date, expiresAt: Date, initiatedBy: String, people: [BoredRequestUser]) {
        self.groupID = groupID
        self.requestID = requestID
        self.activity = activity
        self.postedTime = postedTime
        self.expiresAt = expiresAt
        self.initiatedBy = initiatedBy
        self.people = people
    }
    
    init() {
        groupID = ""
        requestID = ""
        activity = ""
        postedTime = Date()
        expiresAt = Date()
        initiatedBy = ""
        people = [BoredRequestUser]()
    }
}
