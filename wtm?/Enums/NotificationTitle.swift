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
    case sports = "wants to play sports"
    case watchMovie = "wants to watch a movie"
    case workout = "wants to workout"
    
    init?(integer: Int){
        switch integer {
        case 0 : self = .coffeeDate
        case 1 : self = .chill
        case 2 : self = .cityTrip
        case 3 : self = .driveAround
        case 4 : self = .getFood
        case 5 : self = .getIceCream
        case 6 : self = .goOutdoors
        case 7 : self = .goToMall
        case 8 : self = .goToStore
        case 9 : self = .goSwimming
        case 10 : self = .idk
        case 11 : self = .playWithDog
        case 12 : self = .sitAndStare
        case 13 : self = .sports
        case 14 : self = .watchMovie
        case 15 : self = .workout
        default : return nil
        }
    }
}
