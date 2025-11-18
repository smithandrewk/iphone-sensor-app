//
//  SegmentManager.swift
//  Kinetic
//
//  Manages persistent storage of time segments as JSON sidecar files
//

import Foundation

/// Manages time segment persistence and querying
class SegmentManager {
    static let shared = SegmentManager()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - File Management

    /// Get the sidecar segments file URL for a CSV file
    private func segmentsFileURL(for csvFilename: String) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let watchDataDir = documentsURL.appendingPathComponent("watch_data")

        // Remove .csv extension and add .segments.json
        let baseFilename = csvFilename.replacingOccurrences(of: ".csv", with: "")
        return watchDataDir.appendingPathComponent("\(baseFilename).segments.json")
    }

    /// Load segments for a specific CSV file
    func loadSegments(for csvFilename: String) -> [TimeSegment] {
        let fileURL = segmentsFileURL(for: csvFilename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let segmentFile = try decoder.decode(SegmentFile.self, from: data)
            return segmentFile.segments
        } catch {
            print("❌ Error loading segments for \(csvFilename): \(error)")
            return []
        }
    }

    /// Save segments for a specific CSV file
    func saveSegments(_ segments: [TimeSegment], for csvFilename: String) {
        let fileURL = segmentsFileURL(for: csvFilename)

        // Create watch_data directory if needed
        let watchDataDir = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: watchDataDir, withIntermediateDirectories: true)

        let segmentFile = SegmentFile(fileId: csvFilename, segments: segments)

        do {
            let data = try encoder.encode(segmentFile)
            try data.write(to: fileURL, options: .atomic)
            print("💾 Saved \(segments.count) segments for \(csvFilename)")
        } catch {
            print("❌ Error saving segments for \(csvFilename): \(error)")
        }
    }

    // MARK: - Segment Operations

    /// Add a new segment for a file
    func addSegment(_ segment: TimeSegment, to csvFilename: String) {
        var segments = loadSegments(for: csvFilename)
        segments.append(segment)
        saveSegments(segments, for: csvFilename)
    }

    /// Add multiple segments for a file
    func addSegments(_ newSegments: [TimeSegment], to csvFilename: String) {
        var segments = loadSegments(for: csvFilename)
        segments.append(contentsOf: newSegments)
        saveSegments(segments, for: csvFilename)
    }

    /// Update an existing segment
    func updateSegment(_ segment: TimeSegment, in csvFilename: String) {
        var segments = loadSegments(for: csvFilename)
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = segment
            saveSegments(segments, for: csvFilename)
        }
    }

    /// Delete a segment by ID
    func deleteSegment(id: UUID, from csvFilename: String) {
        var segments = loadSegments(for: csvFilename)
        segments.removeAll { $0.id == id }
        saveSegments(segments, for: csvFilename)
    }

    /// Delete all segments for a file
    func deleteAllSegments(for csvFilename: String) {
        let fileURL = segmentsFileURL(for: csvFilename)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Querying

    /// Get all segments with a specific tag
    func getSegments(withTag tag: String, in csvFilename: String) -> [TimeSegment] {
        let segments = loadSegments(for: csvFilename)
        return segments.filter { $0.tags.contains(tag) }
    }

    /// Get segments overlapping a specific time range
    func getSegments(from startTime: TimeInterval, to endTime: TimeInterval, in csvFilename: String) -> [TimeSegment] {
        let segments = loadSegments(for: csvFilename)
        let querySegment = TimeSegment(startTime: startTime, endTime: endTime, tags: [])
        return segments.filter { $0.overlaps(with: querySegment) }
    }

    // MARK: - Export

    /// Export segments to CSV format for ML training
    /// Format: filename,start_time,end_time,tag
    func exportSegmentsAsCSV(for csvFilename: String) -> String {
        let segments = loadSegments(for: csvFilename)

        var csv = "filename,start_time,end_time,tag\n"

        for segment in segments {
            for tag in segment.tags {
                csv += "\(csvFilename),\(segment.startTime),\(segment.endTime),\(tag)\n"
            }
        }

        return csv
    }

    /// Export all segments across all files
    func exportAllSegmentsAsCSV() -> String {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let watchDataDir = documentsURL.appendingPathComponent("watch_data")

        guard let files = try? fileManager.contentsOfDirectory(at: watchDataDir, includingPropertiesForKeys: nil) else {
            return "filename,start_time,end_time,tag\n"
        }

        var csv = "filename,start_time,end_time,tag\n"

        let csvFiles = files.filter { $0.pathExtension == "csv" }
        for csvFile in csvFiles {
            let filename = csvFile.lastPathComponent
            let segments = loadSegments(for: filename)

            for segment in segments {
                for tag in segment.tags {
                    csv += "\(filename),\(segment.startTime),\(segment.endTime),\(tag)\n"
                }
            }
        }

        return csv
    }
}
