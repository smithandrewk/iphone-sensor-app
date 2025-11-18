//
//  RecordingView.swift
//  Kinetic
//
//  Main view for data collection and activity labeling
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @StateObject private var recordingSession = RecordingSession.shared
    @AppStorage("isDataCollectionEnabled") private var isDataCollectionEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Master Data Collection Toggle
                dataCollectionToggle

                // Recording Companion Card (only show when data collection is enabled)
                if isDataCollectionEnabled && recordingSession.isRecording {
                    RecordingCompanionView(session: recordingSession)
                }

                // Watch Status Card
                watchStatusCard

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .onAppear {
            // Send initial data collection state to watch
            watchConnectivity.sendDataCollectionState(enabled: isDataCollectionEnabled)

            // Start recording session if collection is enabled and not already recording
            if isDataCollectionEnabled && !recordingSession.isRecording {
                if recordingSession.startTime == nil {
                    recordingSession.startRecording()
                }
            }

            // Request metadata update from watch
            watchConnectivity.requestMetadataUpdate()
        }
    }

    // MARK: - Subviews

    private var dataCollectionToggle: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $isDataCollectionEnabled) {
                HStack {
                    Image(systemName: isDataCollectionEnabled ? "record.circle.fill" : "stop.circle.fill")
                        .foregroundColor(isDataCollectionEnabled ? .red : .gray)
                    Text("Data Collection")
                        .font(.headline)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: isDataCollectionEnabled) { oldValue, newValue in
                watchConnectivity.sendDataCollectionState(enabled: newValue)

                // Start/stop recording session
                if newValue && !recordingSession.isRecording {
                    recordingSession.startRecording()
                } else if !newValue && recordingSession.isRecording {
                    // Stop recording
                    let timestamps = recordingSession.stopRecording()
                    print("📝 Recording stopped with \(timestamps.count) events")
                }
            }

            Text(isDataCollectionEnabled ? "Recording sensor data on Apple Watch" : "Data collection paused")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isDataCollectionEnabled ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var watchStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⌚ Apple Watch Status")
                .font(.headline)

            HStack(spacing: 8) {
                Circle()
                    .fill(watchConnectivity.isReachable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(watchConnectivity.isReachable ? "Watch Connected" : "Watch Not Reachable")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if watchConnectivity.syncInProgress {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }

            if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                    Text("Watch app installed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
