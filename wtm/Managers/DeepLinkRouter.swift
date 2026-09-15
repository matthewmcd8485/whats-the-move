//
//  DeepLinkRouter.swift
//  wtm?
//
//  Where a notification wants the app to land.
//
//  A push is handled in `AppDelegate` long before the screen that can show it
//  exists: tapping a response button on a cold launch runs `didReceive` while
//  the app is still working out whether anyone is signed in. So the destination
//  is parked here and picked up by whichever view can act on it, however much
//  later that is.
//

import SwiftUI

/// A response chosen from a notification action.
///
/// Both halves of the app's answer to a bored request: the availability that
/// colours the row, and the message shown underneath it.
struct BoredResponseChoice: Hashable, Sendable {
    let status: String
    let substatus: String
}

@Observable
@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// A bored request to open, plus the response already given from the
    /// notification, if the person used one of its buttons.
    struct BoredRequestTarget: Hashable {
        let groupID: String
        let requestID: String
        var chosenResponse: BoredResponseChoice?
    }

    /// Cleared by whoever navigates. Left set, returning to the requests tab
    /// would push the same request again.
    var boredRequest: BoredRequestTarget?

    private init() {}

    func open(groupID: String, requestID: String, chosenResponse: BoredResponseChoice? = nil) {
        boredRequest = BoredRequestTarget(
            groupID: groupID,
            requestID: requestID,
            chosenResponse: chosenResponse
        )
    }

    func clearBoredRequest() {
        boredRequest = nil
    }
}
