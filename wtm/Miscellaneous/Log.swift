//
//  Log.swift
//  wtm?
//
//  Typed os.Logger categories for the project. Use these instead of print()
//  so messages are filterable in Console.app and elided in release builds
//  when appropriate.
//

import Foundation
import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.matthewmcdonnell.wtm"
    
    static let database = Logger(subsystem: subsystem, category: "database")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
