//
//  BoredRequestUser.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/2/21.
//

import Foundation

struct BoredRequestUser {
    let user: User
    var responseStatus: String
    var responseSubstatus: String
    
    init(user: User, responseStatus: String, responseSubstatus: String) {
        self.user = user
        self.responseStatus = responseStatus
        self.responseSubstatus = responseSubstatus
    }
}
