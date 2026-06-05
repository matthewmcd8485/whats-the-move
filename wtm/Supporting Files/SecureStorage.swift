//
//  SecureStorage.swift
//  wtm?
//
//  Typed Keychain accessors for sensitive user data
//  (uid, phone number, FCM token, blocked-user lists).
//
//  Reads transparently migrate values from legacy UserDefaults storage
//  on first access, so existing installs upgrade in place.
//

import Foundation

enum SecureStorage {
    
    private static let service: String = Bundle.main.bundleIdentifier ?? "com.matthewmcdonnell.wtm"
    
    private enum Account: String, CaseIterable {
        case uid
        case phoneNumber
        case fcmToken
        case blockedUsers
        case whoBlockedMe
    }
    
    // MARK: - Public Typed Accessors
    
    static var uid: String? {
        get { readString(.uid) }
        set { writeString(newValue, for: .uid) }
    }
    
    static var phoneNumber: String? {
        get { readString(.phoneNumber) }
        set { writeString(newValue, for: .phoneNumber) }
    }
    
    static var fcmToken: String? {
        get { readString(.fcmToken) }
        set { writeString(newValue, for: .fcmToken) }
    }
    
    static var blockedUsers: [String] {
        get { readArray(.blockedUsers) }
        set { writeArray(newValue, for: .blockedUsers) }
    }
    
    static var whoBlockedMe: [String] {
        get { readArray(.whoBlockedMe) }
        set { writeArray(newValue, for: .whoBlockedMe) }
    }
    
    static func clear() {
        for account in Account.allCases {
            try? KeychainItem(service: service, account: account.rawValue).deleteItem()
            UserDefaults.standard.removeObject(forKey: account.rawValue)
        }
    }
    
    // MARK: - String Storage
    
    private static func readString(_ account: Account) -> String? {
        if let value = try? KeychainItem(service: service, account: account.rawValue).readItem(), !value.isEmpty {
            return value
        }
        // Migration: copy from legacy UserDefaults storage and remove it
        if let legacy = UserDefaults.standard.string(forKey: account.rawValue) {
            writeString(legacy, for: account)
            UserDefaults.standard.removeObject(forKey: account.rawValue)
            return legacy
        }
        return nil
    }
    
    private static func writeString(_ value: String?, for account: Account) {
        guard let value = value else {
            try? KeychainItem(service: service, account: account.rawValue).deleteItem()
            return
        }
        try? KeychainItem(service: service, account: account.rawValue).saveItem(value)
    }
    
    // MARK: - Array Storage (JSON-encoded)
    
    private static func readArray(_ account: Account) -> [String] {
        if let json = try? KeychainItem(service: service, account: account.rawValue).readItem(),
           let data = json.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        // Migration: copy from legacy UserDefaults storage and remove it
        if let legacy = UserDefaults.standard.stringArray(forKey: account.rawValue) {
            writeArray(legacy, for: account)
            UserDefaults.standard.removeObject(forKey: account.rawValue)
            return legacy
        }
        return []
    }
    
    private static func writeArray(_ value: [String], for account: Account) {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        try? KeychainItem(service: service, account: account.rawValue).saveItem(json)
    }
}
