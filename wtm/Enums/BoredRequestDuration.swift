//
//  BoredRequestDuration.swift
//  wtm?
//
//  How long a bored request stays open.
//

import Foundation

/// The stops the expiry slider offers when sending a bored request.
///
/// Every request used to get a flat two hours, which is still the default and
/// the longest on offer here. The shorter stops are for a "right now"
/// invitation, which reads as stale long before two hours are up; a request
/// that needs longer gets extended from the request itself once it's out.
enum BoredRequestDuration: Int, CaseIterable {
    case halfHour = 30
    case fortyFiveMinutes = 45
    case hour = 60
    case ninetyMinutes = 90
    case twoHours = 120

    /// What a request got before the duration was adjustable.
    static let `default` = BoredRequestDuration.twoHours

    /// The raw value is the length in minutes.
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    var label: String {
        switch self {
        case .halfHour: "30 minutes"
        case .fortyFiveMinutes: "45 minutes"
        case .hour: "1 hour"
        case .ninetyMinutes: "90 minutes"
        case .twoHours: "2 hours"
        }
    }

    /// How this reads as time added to a request that's already out, where
    /// "1 hour" would want to be "another hour".
    var extensionLabel: String {
        switch self {
        case .halfHour: "another 30 minutes"
        case .fortyFiveMinutes: "another 45 minutes"
        case .hour: "another hour"
        case .ninetyMinutes: "another 90 minutes"
        case .twoHours: "another 2 hours"
        }
    }

    // MARK: - Slider positions

    /// Where this sits on the slider. The stops are spaced evenly rather than
    /// in proportion to their length, so each one is equally easy to land on —
    /// proportional spacing would crowd the three short stops into the first
    /// quarter of the track.
    var stop: Double { Double(Self.allCases.firstIndex(of: self) ?? 0) }

    static var stopRange: ClosedRange<Double> { 0...Double(allCases.count - 1) }

    /// The nearest stop to a slider position, which arrives as a `Double`.
    init(stop: Double) {
        let index = Int(stop.rounded())
        self = Self.allCases[min(max(index, 0), Self.allCases.count - 1)]
    }
}
