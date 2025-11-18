//
//  TimeSegment.swift
//  Kinetic
//
//  Represents a time range with associated activity tags
//

import Foundation

/// Represents a labeled time segment within a recording
struct TimeSegment: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let startTime: TimeInterval  // Seconds from recording start
    let endTime: TimeInterval    // Seconds from recording start
    let tags: [String]           // Activity labels for this segment
    let createdAt: Date

    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, tags: [String], createdAt: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.tags = tags
        self.createdAt = createdAt
    }

    /// Duration of the segment in seconds
    var duration: TimeInterval {
        return endTime - startTime
    }

    /// Check if this segment overlaps with another
    func overlaps(with other: TimeSegment) -> Bool {
        return !(endTime <= other.startTime || startTime >= other.endTime)
    }

    /// Check if a specific time is contained in this segment
    func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
}

/// Container for segments associated with a specific CSV file
struct SegmentFile: Codable {
    let fileId: String  // Associated CSV filename
    var segments: [TimeSegment]
    let version: Int = 1  // Schema version for future compatibility

    init(fileId: String, segments: [TimeSegment] = []) {
        self.fileId = fileId
        self.segments = segments
    }
}
