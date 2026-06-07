//
//  Status.swift
//  wtm?
//

import Foundation

enum Status: String, CaseIterable, Identifiable {
    case available = "available"
    case busy = "busy"
    case doNotDisturb = "do not disturb"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .available: return "available"
        case .busy: return "busy"
        case .doNotDisturb: return "stfu!"
        }
    }

    var backgroundColorName: String {
        switch self {
        case .available: return "lightGreenOnLight"
        case .busy: return "lightYellowOnLight"
        case .doNotDisturb: return "lightRedOnLight"
        }
    }

    var iconName: String {
        switch self {
        case .available: return "checkmark.seal"
        case .busy: return "exclamationmark.bubble"
        case .doNotDisturb: return "nosign"
        }
    }

    var iconColorName: String {
        switch self {
        case .available: return "darkGreenOnLight"
        case .busy: return "darkYellowOnLight"
        case .doNotDisturb: return "darkRedOnLight"
        }
    }

    var descriptionText: String {
        switch self {
        case .available: return "let's do something right this instant!"
        case .busy: return "i have better things to do than hang out with you"
        case .doNotDisturb: return "don't even think about talking to me right now"
        }
    }

    var titleTrailing: String? {
        switch self {
        case .doNotDisturb: return "(silences notifications)"
        default: return nil
        }
    }

    var substatuses: [String] {
        switch self {
        case .available:
            return ["ready to mingle", "literally so bored", "let's do something!", "hmu!", "need something to do", "this app is dumb"]
        case .busy:
            return ["already have plans", "will be free later", "not on my phone today", "don't know what's happening", "tied up at work", "this app is dumb"]
        case .doNotDisturb:
            return ["don't talk to me", "i don't like you", "i'm not free today", "call me when i care", "leave me alone", "this app is dumb"]
        }
    }
}
