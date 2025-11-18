//
//  RecordingSession.swift
//  Kinetic
//
//  Manages the state of a recording session with activity tracking
//

import Foundation
import Combine

/// Manages activity tracking during a recording session
class RecordingSession: ObservableObject {
    static let shared = RecordingSession()

    @Published var isRecording: Bool = false
    @Published var startTime: Date?
    @Published var activityTimestamps: [ActivityTimestamp] = []
    @Published var currentActivities: Set<String> = []  // Activities currently active

    private let defaults = UserDefaults.standard
    private let startTimeKey = "recordingSessionStartTime"
    private let timestampsKey = "recordingSessionTimestamps"
    private let currentActivitiesKey = "recordingSessionCurrentActivities"

    private init() {
        // Load persisted session state
        loadPersistedState()
    }

    /// Start a new recording session
    func startRecording() {
        startTime = Date()
        isRecording = true
        activityTimestamps = []
        currentActivities = []
        saveState()
        print("📝 Recording session started")
    }

    /// Load persisted recording state
    private func loadPersistedState() {
        if let savedStartTime = defaults.object(forKey: startTimeKey) as? Date {
            startTime = savedStartTime
            isRecording = true

            // Load timestamps
            if let timestampsData = defaults.data(forKey: timestampsKey),
               let timestamps = try? JSONDecoder().decode([ActivityTimestamp].self, from: timestampsData) {
                activityTimestamps = timestamps
            }

            // Load current activities
            if let activitiesArray = defaults.stringArray(forKey: currentActivitiesKey) {
                currentActivities = Set(activitiesArray)
            }

            print("📝 Restored recording session from \(savedStartTime)")
        }
    }

    /// Save current state to UserDefaults
    private func saveState() {
        if let start = startTime {
            defaults.set(start, forKey: startTimeKey)
        }

        if let timestampsData = try? JSONEncoder().encode(activityTimestamps) {
            defaults.set(timestampsData, forKey: timestampsKey)
        }

        defaults.set(Array(currentActivities), forKey: currentActivitiesKey)
    }

    /// Clear persisted state
    private func clearState() {
        defaults.removeObject(forKey: startTimeKey)
        defaults.removeObject(forKey: timestampsKey)
        defaults.removeObject(forKey: currentActivitiesKey)
    }

    /// Stop the recording session and return all timestamps
    func stopRecording() -> [ActivityTimestamp] {
        isRecording = false
        let timestamps = activityTimestamps

        // Auto-stop any currently active activities
        for activity in currentActivities {
            toggleActivity(activity)
        }

        clearState()
        print("📝 Recording session stopped - \(timestamps.count) events recorded")
        return timestamps
    }

    /// Toggle an activity on/off with timestamp
    func toggleActivity(_ activity: String) {
        guard isRecording, let start = startTime else {
            print("⚠️ Cannot mark activity - not recording")
            return
        }

        let now = Date()
        let timestamp = now.timeIntervalSince(start)

        let action: ActivityAction
        if currentActivities.contains(activity) {
            // Stop the activity
            currentActivities.remove(activity)
            action = .stopped
        } else {
            // Start the activity
            currentActivities.insert(activity)
            action = .started
        }

        let event = ActivityTimestamp(
            activity: activity,
            action: action,
            timestamp: timestamp,
            markedAt: now
        )

        activityTimestamps.append(event)
        saveState()  // Persist after each activity change
        print("📝 Activity '\(activity)' \(action.rawValue) at \(String(format: "%.1f", timestamp))s")

        // Auto-save segments to most recent file after each activity change
        saveSegmentsToMostRecentFile()
    }

    /// Save current activity segments to the most recent CSV file
    private func saveSegmentsToMostRecentFile() {
        // Find the most recent CSV file
        let csvFileManager = CSVFileManager()
        let files = csvFileManager.getCSVFilesWithMetadata()

        guard let mostRecentFile = files.max(by: { $0.creationDate < $1.creationDate }) else {
            print("📝 No CSV file found to save segments to")
            return
        }

        // Get current elapsed time as duration
        let duration = elapsedTime

        // Convert timestamps to segments
        let segments = toSegments(totalDuration: duration)

        // Save to JSON (this will overwrite previous segments for this session)
        SegmentManager.shared.saveSegments(segments, for: mostRecentFile.fileName)
        print("📝 Auto-saved \(segments.count) segments to \(mostRecentFile.fileName)")
    }

    /// Get elapsed time since recording started
    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Convert activity timestamps to time segments for export
    func toSegments(totalDuration: TimeInterval) -> [TimeSegment] {
        var segments: [TimeSegment] = []
        var activityStarts: [String: TimeInterval] = [:]

        // Process each timestamp event
        for event in activityTimestamps.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch event.action {
            case .started:
                activityStarts[event.activity] = event.timestamp
            case .stopped:
                if let startTime = activityStarts[event.activity] {
                    let segment = TimeSegment(
                        startTime: startTime,
                        endTime: event.timestamp,
                        tags: [event.activity]
                    )
                    segments.append(segment)
                    activityStarts.removeValue(forKey: event.activity)
                }
            }
        }

        // Handle any activities that were never stopped
        for (activity, startTime) in activityStarts {
            let segment = TimeSegment(
                startTime: startTime,
                endTime: totalDuration,
                tags: [activity]
            )
            segments.append(segment)
        }

        return segments
    }
}
