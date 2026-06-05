//
//  UIApplication.swift
//  wtm?
//
//  Created by Matthew McDonnell on 1/17/22.
//

import UIKit
import UserNotifications

extension UIApplication {
    struct Constants {
        static let CFBundleShortVersionString = "CFBundleShortVersionString"
        static let badgeCountKey = "wtmBadgeCount"
    }
    
    class func appVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: Constants.CFBundleShortVersionString) as! String
    }
    
    class func appBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }
    
    class func versionBuild() -> String {
        let version = appVersion(), build = appBuild()
        
        return version == build ? "v\(version)" : "v\(version)(\(build))"
    }
    
    class func resetBadgeCount() {
        UserDefaults.standard.set(0, forKey: Constants.badgeCountKey)
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    class func incrementBadgeCount() {
        let newCount = UserDefaults.standard.integer(forKey: Constants.badgeCountKey) + 1
        UserDefaults.standard.set(newCount, forKey: Constants.badgeCountKey)
        UNUserNotificationCenter.current().setBadgeCount(newCount)
    }
}
