//
//  NotificationTitle.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/28/21.
//
//  The activity attached to a bored request. The raw value is the phrase that
//  appears in the push ("<name> wants to get coffee"), which is also what gets
//  written to Firestore.
//
//  This used to be three parallel lists kept in sync by hand: the cases here,
//  `PickerData.collectionViewData` for the grid labels, `CategoryImages` for the
//  tile artwork, and an `init?(integer:)` mapping grid positions onto cases —
//  whose order already disagreed with the declaration order. Label and image
//  now hang off the case, so there's one list and nothing to keep aligned.
//

import Foundation

public enum NotificationTitle: String, CaseIterable, Identifiable, Sendable {
    case coffeeDate = "wants to get coffee"
    case chill = "wants to chill"
    case cityTrip = "wants to go downtown"
    case dateNight = "wants a kiss"
    case driveAround = "wants to drive around"
    case getFood = "is hungry"
    case getIceCream = "wants ice cream"
    case goOutdoors = "wants to go outside"
    case goToMall = "wants to go to the mall"
    case goToStore = "wants to go to the store"
    case goSwimming = "wants to go swimming"
    case idk = "is bored"
    case playWithDog = "wants to play with a dog"
    case sleepover = "wants to sleep with you"
    case sitAndStare = "wants to stare at you"
    case sports = "wants to play sports"
    case watchMovie = "wants to watch a movie"
    case workout = "wants to workout"

    public var id: String { rawValue }

    /// Label shown on the activity picker tile.
    public var label: String {
        switch self {
        case .coffeeDate: "coffee date"
        case .chill: "chill"
        case .cityTrip: "city trip"
        case .dateNight: "date night"
        case .driveAround: "drive around"
        case .getFood: "get food"
        case .getIceCream: "get ice cream"
        case .goOutdoors: "go outdoors"
        case .goToMall: "go to the mall"
        case .goToStore: "go to the store"
        case .goSwimming: "go swimming"
        case .idk: "idk"
        case .playWithDog: "play with dog"
        case .sleepover: "sleepover"
        case .sitAndStare: "sit and stare at each other"
        case .sports: "sports"
        case .watchMovie: "watch a movie"
        case .workout: "workout"
        }
    }

    /// Asset name for the tile artwork and the request background.
    public var imageName: String {
        switch self {
        case .coffeeDate: "coffee"
        case .chill: "chill"
        case .cityTrip: "city"
        case .dateNight: "date night"
        case .driveAround: "drive"
        case .getFood: "food"
        case .getIceCream: "ice cream"
        case .goOutdoors: "outdoors"
        case .goToMall: "mall"
        case .goToStore: "store"
        case .goSwimming: "swimming"
        case .idk: "idk"
        case .playWithDog: "dog"
        case .sleepover: "sleepover"
        case .sitAndStare: "stare"
        case .sports: "sports"
        case .watchMovie: "movie"
        case .workout: "workout"
        }
    }

    /// Resolves an activity string read back out of Firestore. Unknown values
    /// fall back to "chill", which is what the old if/else chain did.
    public init(activity: String) {
        self = NotificationTitle(rawValue: activity) ?? .chill
    }
}
