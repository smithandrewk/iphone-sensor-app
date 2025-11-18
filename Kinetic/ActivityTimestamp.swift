//
//  ActivityTimestamp.swift
//  Kinetic
//
//  Represents a single activity event (start or stop) during a recording session
//

import Foundation

/// Defines whether an activity was started or stopped
enum ActivityAction: String, Codable {
    case started
    case stopped
}

/// Represents a single activity event with timestamp
struct ActivityTimestamp: Identifiable, Codable, Equatable {
    let id: UUID
    let activity: String
    let action: ActivityAction
    let timestamp: TimeInterval  // Seconds from recording start
    let markedAt: Date  // Absolute time when user marked this

    init(id: UUID = UUID(), activity: String, action: ActivityAction, timestamp: TimeInterval, markedAt: Date = Date()) {
        self.id = id
        self.activity = activity
        self.action = action
        self.timestamp = timestamp
        self.markedAt = markedAt
    }
}
