//
//  BoredResponseCategory.swift
//  wtm?
//
//  The availability half of an answer to a bored request.
//
//  Firestore stores it as a free-form string, and the three original values
//  were spelled out by hand at every site that read or wrote one. They're
//  collected here because there's now a fourth: a reply that arrived without a
//  category at all, which is what a custom message is when someone didn't say
//  whether they're actually free.
//

import SwiftUI

enum BoredResponseCategory: String, CaseIterable, Identifiable, Sendable {
    case available = "available"
    case busy = "busy"
    case notAvailable = "not available"
    /// Replied with a message, but didn't say whether they're free.
    case uncategorized = "custom"

    public var id: String { rawValue }

    /// What the request shows for someone who hasn't answered. Not a case —
    /// it's the absence of one, and it can't be chosen.
    static let noResponse = "no response"

    /// The three that have their own list of canned messages. `uncategorized`
    /// is reachable only by writing your own, so it has no preset screen.
    static let presetCategories: [BoredResponseCategory] = [.available, .busy, .notAvailable]

    var iconName: String {
        switch self {
        case .available: "checkmark.circle"
        case .busy: "exclamationmark.circle"
        case .notAvailable: "nosign"
        // Not a traffic light, because it isn't one: this reply never picked a
        // colour, so it gets its own.
        case .uncategorized: "text.bubble"
        }
    }

    var color: Color {
        switch self {
        case .available: .green
        case .busy: .wtmDarkYellow
        case .notAvailable: .red
        case .uncategorized: .purple
        }
    }

    /// Wording for the response menu.
    var menuLabel: String {
        switch self {
        case .available: "yeah, i'm free"
        case .busy: "mmm, maybe?"
        case .notAvailable: "no, i'm not free"
        case .uncategorized: "no comment"
        }
    }

    /// Wording for the compact category picker on the custom reply screen.
    var shortLabel: String {
        switch self {
        case .available: "free"
        case .busy: "maybe"
        case .notAvailable: "nope"
        case .uncategorized: "no category"
        }
    }

    /// Heading on the message-picking screens.
    var headline: String {
        switch self {
        case .available: "you are available"
        case .busy: "you are busy"
        case .notAvailable: "you are not available"
        case .uncategorized: "no category"
        }
    }

    /// The message written by the matching one-tap notification action, which
    /// is the wording of the button itself — so what shows up in the app is
    /// what was actually pressed.
    var notificationActionMessage: String {
        switch self {
        case .available: "count me in!"
        case .busy: "might be busy today"
        case .notAvailable: "stop talking to me"
        case .uncategorized: ""
        }
    }

    /// The canned messages offered after picking this category.
    var presetMessages: [String] {
        switch self {
        case .available:
            [
                "lmk what time", "sounds good", "i'll be there!", "i'll drive",
                "on my way!", "ok!", "so excited!", "can't wait to see you all", "joe"
            ]
        case .busy:
            [
                "already have plans", "maybe later?", "tomorrow would work better",
                "don't know what's happening", "maybe when i get off work",
                "gotta ask my parents", "won't have a car today", "ask me again in an hour", "joe"
            ]
        case .notAvailable:
            [
                "already have plans today", "i'm not in town", "i don't like you",
                "i'm not free today", "call me when i care", "leave me alone",
                "at work all day", "got dragged into some other stuff", "joe"
            ]
        case .uncategorized:
            []
        }
    }
}
