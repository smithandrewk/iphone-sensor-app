//
//  ContentView.swift
//  Kinetic
//
//  Main app container with tab navigation
//

import SwiftUI

/// File synchronization state
enum SyncState: String, Codable, Hashable {
    case pending      // Metadata known, file not yet transferred from watch
    case transferring // Transfer in progress
    case synced       // Successfully transferred and saved to iPhone
}

/// Source device for the file
enum DeviceType: String, Codable, Hashable {
    case watch
    case phone // Reserved for future use if phone recording is re-enabled
}

/// Holds file metadata for display and sorting
struct FileInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let creationDate: Date
    let modificationDate: Date
    var syncState: SyncState = .synced
    var transferProgress: Double = 0.0
    var sourceDevice: DeviceType = .watch

    var fileName: String {
        url.lastPathComponent
    }

    /// The actual data collection date parsed from the filename
    /// Format: sensor_data_2025-11-17_14-30-00.csv
    /// Falls back to file creation date if parsing fails
    var dataDate: Date {
        let filename = url.lastPathComponent

        // Extract the date portion: "sensor_data_YYYY-MM-DD_HH-mm-ss.csv"
        // Pattern: sensor_data_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})
        let components = filename.components(separatedBy: "_")

        // Need at least: ["sensor", "data", "YYYY-MM-DD", "HH-mm-ss.csv"]
        guard components.count >= 4,
              components[0] == "sensor",
              components[1] == "data" else {
            // Fallback to creation date if filename doesn't match expected format
            return creationDate
        }

        let datePart = components[2] // "YYYY-MM-DD"
        let timePart = components[3].replacingOccurrences(of: ".csv", with: "") // "HH-mm-ss"

        // Combine into ISO 8601 format: "YYYY-MM-DD HH:mm:ss"
        let dateTimeString = "\(datePart) \(timePart.replacingOccurrences(of: "-", with: ":"))"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current

        if let parsedDate = dateFormatter.date(from: dateTimeString) {
            return parsedDate
        } else {
            // Fallback to creation date if parsing fails
            return creationDate
        }
    }
}

/// Sorting options for the file list
enum FileSortOption: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case largestFirst = "Largest First"
    case smallestFirst = "Smallest First"
}

struct ContentView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager

    var body: some View {
        TabView {
            RecordingView()
                .environmentObject(watchConnectivity)
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }

            FilesView()
                .environmentObject(watchConnectivity)
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - ShareSheet helper

struct ShareSheet: UIViewControllerRepresentable {
    let fileURLs: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
