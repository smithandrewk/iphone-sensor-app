//
//  SensorWatchApp.swift
//  SensorWatch Watch App
//
//  Main app entry point for Apple Watch sensor recording
//

import SwiftUI

@main
struct KineticWatchApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("⌚ App became active")
                appState.handleAppBecameActive()
            case .inactive:
                print("⌚ App became inactive")
            case .background:
                print("⌚ App entered background")
                appState.handleAppEnteredBackground()
            @unknown default:
                break
            }
        }
    }
}

/// Manages app-wide state and background processing
class AppState: ObservableObject {
    let motionRecorder = MotionRecorder()
    private var backgroundTaskTimer: Timer?
    private var hasLaunched = false
    private var previousFileCount = 0

    init() {
        // Initialize WatchConnectivity
        _ = WatchConnectivityManager.shared

        // Listen for data collection state changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataCollectionStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let enabled = userInfo["enabled"] as? Bool else { return }

            if enabled {
                print("⌚ Data collection enabled - starting recording")
                self.motionRecorder.startContinuousRecording()
            } else {
                print("⌚ Data collection disabled - processing remaining data then stopping")
                // Process any remaining unprocessed data before stopping
                self.motionRecorder.processAndSaveUnprocessedData()
                self.motionRecorder.stopContinuousRecording()
                print("⌚ Recording stopped and remaining data saved")
            }
        }

        // Start continuous recording and process data on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if !self.hasLaunched {
                self.hasLaunched = true
                print("⌚ SensorWatch app initialized")

                // Only start recording if data collection is enabled
                if WatchConnectivityManager.shared.isDataCollectionEnabled {
                    self.motionRecorder.startContinuousRecording()
                    self.motionRecorder.processAndSaveUnprocessedData()
                } else {
                    print("⌚ Data collection disabled - not starting recording")
                }

                self.scheduleBackgroundProcessing()

                // Initial metadata sync
                WatchConnectivityManager.shared.syncFileMetadata()

                // Track initial file count
                self.previousFileCount = self.motionRecorder.getCSVFiles().count
            }
        }
    }

    func handleAppBecameActive() {
        // Process and save data when app comes to foreground (only if collection enabled)
        if WatchConnectivityManager.shared.isDataCollectionEnabled {
            motionRecorder.processAndSaveUnprocessedData()
        } else {
            print("⌚ Data collection disabled - skipping processing on app activation")
        }

        // Notify UI to refresh file list
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)

        // Sync metadata
        WatchConnectivityManager.shared.syncFileMetadata()

        // Restart timer if needed
        if backgroundTaskTimer == nil {
            scheduleBackgroundProcessing()
        }
    }

    func handleAppEnteredBackground() {
        // Timer will continue running in background on watchOS
        print("⌚ Timer will continue processing in background")

        // Sync metadata before backgrounding
        WatchConnectivityManager.shared.syncFileMetadata()
    }

    // MARK: - Background Processing

    /// Schedule a timer to periodically process sensor data
    /// On watchOS, this runs every 30 seconds while app is active or in background
    private func scheduleBackgroundProcessing() {
        // Cancel any existing timer
        backgroundTaskTimer?.invalidate()

        // Create a new timer that fires every 30 seconds
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("⏰ Background timer fired - processing data")

            // Only process data if collection is enabled
            guard WatchConnectivityManager.shared.isDataCollectionEnabled else {
                print("⏰ Data collection disabled - skipping processing")
                return
            }

            self.motionRecorder.processAndSaveUnprocessedData()

            // Check if new files were created
            let currentFileCount = self.motionRecorder.getCSVFiles().count
            if currentFileCount > self.previousFileCount {
                print("⌚ New files detected: \(currentFileCount - self.previousFileCount) files")

                // Get new files
                let allFiles = self.motionRecorder.getCSVFiles()
                let newFiles = Array(allFiles.suffix(currentFileCount - self.previousFileCount))

                // Queue new files for transfer
                for fileURL in newFiles {
                    WatchConnectivityManager.shared.queueFileForTransfer(fileURL)
                }

                self.previousFileCount = currentFileCount

                // Update metadata
                WatchConnectivityManager.shared.syncFileMetadata()
            }

            // Notify UI to refresh file list
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
        }

        // Ensure timer runs even when UI is scrolling
        if let timer = backgroundTaskTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("⏰ Scheduled background processing timer (30s interval)")
    }

    deinit {
        backgroundTaskTimer?.invalidate()
    }
}
