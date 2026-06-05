//
//  NotificationBody.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/28/21.
//

import Foundation

public enum NotificationTitle: String {
    public typealias RawValue = String
    
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
    case sitAndStare = "wants to stare at you"
    case sleepover = "wants to sleep with you"
    case sports = "wants to play sports"
    case watchMovie = "wants to watch a movie"
    case workout = "wants to workout"
    
    init?(integer: Int){
        switch integer {
        case 0 : self = .coffeeDate
        case 1 : self = .chill
        case 2 : self = .cityTrip
        case 3 : self = .dateNight
        case 4 : self = .driveAround
        case 5 : self = .getFood
        case 6 : self = .getIceCream
        case 7 : self = .goOutdoors
        case 8 : self = .goToMall
        case 9 : self = .goToStore
        case 10 : self = .goSwimming
        case 11 : self = .idk
        case 12 : self = .playWithDog
        case 13 : self = .sleepover
        case 14 : self = .sitAndStare
        case 15 : self = .sports
        case 16 : self = .watchMovie
        case 17 : self = .workout
        default : return nil
        }
    }
}
