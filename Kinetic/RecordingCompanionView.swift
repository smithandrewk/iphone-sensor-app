//
//  RecordingCompanionView.swift
//  Kinetic
//
//  Floating companion card for real-time activity marking during recording
//

import SwiftUI

struct RecordingCompanionView: View {
    @ObservedObject var session: RecordingSession
    @State private var showCustomActivitySheet = false
    @State private var showActivitySettings = false
    @State private var currentTime = Date()
    @AppStorage("pinnedActivities") private var pinnedActivitiesData: Data = Data()

    // Timer to update elapsed time display
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Predefined activities
    private let defaultActivities = ["Sitting", "Standing", "Walking", "Running", "Stairs"]

    private var pinnedActivities: [String] {
        (try? JSONDecoder().decode([String].self, from: pinnedActivitiesData)) ?? []
    }

    private var displayedActivities: [String] {
        let pinned = pinnedActivities
        return pinned.isEmpty ? defaultActivities : pinned
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            header

            // Activity Buttons Grid
            activityGrid

            // Activity Timeline
            if !session.activityTimestamps.isEmpty {
                activityTimeline
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .sheet(isPresented: $showCustomActivitySheet) {
            CustomActivitySheet(session: session)
        }
        .sheet(isPresented: $showActivitySettings) {
            ActivitySettingsSheet()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.3)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording on Watch")
                        .font(.headline)
                    Text(formattedElapsedTime)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Activity count badge
            if !session.currentActivities.isEmpty {
                Text("\(session.currentActivities.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.blue)
                    .clipShape(Circle())
            }

            // Settings button
            Button(action: { showActivitySettings = true }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var activityGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(displayedActivities, id: \.self) { activity in
                ActivityButton(
                    activity: activity,
                    isActive: session.currentActivities.contains(activity),
                    action: { session.toggleActivity(activity) }
                )
            }

            // Custom activity button
            Button(action: { showCustomActivitySheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Custom")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
    }

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Timeline")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.activityTimestamps.reversed()) { timestamp in
                        ActivityTimelineItem(timestamp: timestamp)
                    }
                }
            }
            .frame(height: 50)
        }
    }

    private var formattedElapsedTime: String {
        guard let startTime = session.startTime else {
            return "0:00"
        }

        let elapsed = currentTime.timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) / 60 % 60
        let seconds = Int(elapsed) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Activity Button

struct ActivityButton: View {
    let activity: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                Image(systemName: iconForActivity(activity))
                Text(activity)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(8)
        }
    }

    private func iconForActivity(_ activity: String) -> String {
        switch activity.lowercased() {
        case "sitting":   return "figure.seated.side"
        case "standing":  return "figure.stand"
        case "walking":   return "figure.walk"
        case "running":   return "figure.run"
        case "stairs":    return "figure.stairs"
        case "biking":    return "bicycle"
        case "driving":   return "car.fill"
        case "cooking":   return "fork.knife"
        case "cleaning":  return "sparkles"
        case "reading":   return "book.fill"
        case "typing":    return "keyboard"
        default:          return "star.fill"
        }
    }
}

// MARK: - Activity Timeline Item

struct ActivityTimelineItem: View {
    let timestamp: ActivityTimestamp

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: timestamp.action == .started ? "play.circle.fill" : "stop.circle.fill")
                .foregroundColor(timestamp.action == .started ? .green : .red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(timestamp.activity)
                    .font(.caption2.bold())
                Text(formatTimestamp(timestamp.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Custom Activity Sheet

struct CustomActivitySheet: View {
    @ObservedObject var session: RecordingSession
    @State private var activityName = ""
    @Environment(\.dismiss) private var dismiss

    private let suggestions = [
        "Folding Laundry", "Cooking", "Cleaning",
        "Typing", "Reading", "Talking", "Eating"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Activity name", text: $activityName)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Text("Suggestions")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { activityName = suggestion }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Custom Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmed = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            session.toggleActivity(trimmed)
                            dismiss()
                        }
                    }
                    .disabled(activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Activity Settings Sheet

struct ActivitySettingsSheet: View {
    @AppStorage("pinnedActivities") private var pinnedActivitiesData: Data = Data()
    @Environment(\.dismiss) private var dismiss

    private let defaultActivities = ["Sitting", "Standing", "Walking", "Running", "Stairs",
                                      "Biking", "Driving", "Cooking", "Cleaning", "Reading", "Typing"]

    private var pinnedActivities: [String] {
        (try? JSONDecoder().decode([String].self, from: pinnedActivitiesData)) ?? []
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Pin your most used activities to show them in the companion card.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Available Activities") {
                    ForEach(defaultActivities, id: \.self) { activity in
                        ActivityToggleRow(
                            activity: activity,
                            isPinned: pinnedActivities.contains(activity),
                            onToggle: { togglePin(activity) }
                        )
                    }
                }
            }
            .navigationTitle("Activity Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func togglePin(_ activity: String) {
        var pinned = pinnedActivities
        if let index = pinned.firstIndex(of: activity) {
            pinned.remove(at: index)
        } else {
            pinned.append(activity)
        }
        // Save directly to AppStorage
        pinnedActivitiesData = (try? JSONEncoder().encode(pinned)) ?? Data()
    }
}

struct ActivityToggleRow: View {
    let activity: String
    let isPinned: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: iconForActivity(activity))
                .foregroundColor(.blue)
            Text(activity)
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                    .foregroundColor(isPinned ? .blue : .gray)
            }
            .buttonStyle(.plain)
        }
    }

    private func iconForActivity(_ activity: String) -> String {
        switch activity.lowercased() {
        case "sitting":   return "figure.seated.side"
        case "standing":  return "figure.stand"
        case "walking":   return "figure.walk"
        case "running":   return "figure.run"
        case "stairs":    return "figure.stairs"
        case "biking":    return "bicycle"
        case "driving":   return "car.fill"
        case "cooking":   return "fork.knife"
        case "cleaning":  return "sparkles"
        case "reading":   return "book.fill"
        case "typing":    return "keyboard"
        default:          return "star.fill"
        }
    }
}
