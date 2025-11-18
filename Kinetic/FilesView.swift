//
//  FilesView.swift
//  Kinetic
//
//  File management view for sensor data files
//

import SwiftUI

struct FilesView: View {
    let csvFileManager = CSVFileManager()
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State var fileInfos: [FileInfo] = []
    @State var sortOption: FileSortOption = .newestFirst
    @State var showShareSheet = false
    @State var filesToShare: [URL] = []
    @State var showDeleteAllConfirmation = false
    @State var filesCurrentlyTransferring: Set<String> = []

    /// Returns sorted files based on current sort option
    var sortedFiles: [FileInfo] {
        switch sortOption {
        case .nameAscending:
            return fileInfos.sorted { $0.fileName < $1.fileName }
        case .nameDescending:
            return fileInfos.sorted { $0.fileName > $1.fileName }
        case .newestFirst:
            return fileInfos.sorted { $0.dataDate > $1.dataDate }
        case .oldestFirst:
            return fileInfos.sorted { $0.dataDate < $1.dataDate }
        case .largestFirst:
            return fileInfos.sorted { $0.size > $1.size }
        case .smallestFirst:
            return fileInfos.sorted { $0.size < $1.size }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Watch sync controls
            watchSyncControls

            // File count and sort picker
            HStack(spacing: 10) {
                Text("Files: \(fileInfos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Sort by", selection: $sortOption) {
                    ForEach(FileSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
            .padding(.horizontal)

            // Action buttons
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Spacer()

                    Button("Share All Files") {
                        if !fileInfos.isEmpty {
                            filesToShare = fileInfos.map { $0.url }
                            showShareSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fileInfos.isEmpty)

                    Button("Share Labels") {
                        exportAndShareLabels()
                    }
                    .buttonStyle(.bordered)
                    .disabled(fileInfos.isEmpty)
                }

                HStack(spacing: 10) {
                    Spacer()

                    Button("Delete All") {
                        showDeleteAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(fileInfos.isEmpty)
                }
            }
            .padding(.horizontal)

            // File list
            List {
                ForEach(sortedFiles) { fileInfo in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // Date and time with sync state badge
                            HStack(spacing: 6) {
                                Text(formatDataDate(fileInfo.dataDate))
                                    .font(.system(.body, design: .default))
                                    .fontWeight(.medium)
                                    .opacity(fileInfo.syncState == .pending ? 0.5 : 1.0)

                                // Sync state badge
                                if fileInfo.syncState == .pending {
                                    Text("⌚ On Watch")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                } else if fileInfo.syncState == .transferring {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                            }

                            // File size
                            Text(formatFileSize(fileInfo.size))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .opacity(fileInfo.syncState == .pending ? 0.5 : 1.0)
                        }
                        Spacer()

                        if fileInfo.syncState == .pending {
                            // Download button for pending files
                            Button(action: {
                                print("📱 Requesting download of: \(fileInfo.fileName)")
                                filesCurrentlyTransferring.insert(fileInfo.fileName)
                                refreshFiles()
                                watchConnectivity.requestFile(fileInfo.fileName)
                            }) {
                                Image(systemName: "arrow.down.circle")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!watchConnectivity.isReachable)
                        } else if fileInfo.syncState == .transferring {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            // Share button for synced files
                            Button("Share") {
                                if FileManager.default.fileExists(atPath: fileInfo.url.path) {
                                    filesToShare = [fileInfo.url]
                                    showShareSheet = true
                                } else {
                                    print("File doesn't exist: \(fileInfo.url.path)")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .onDelete(perform: deleteFiles)
            }
        }
        .onAppear {
            print("📱 FilesView appeared - loading files")
            refreshFiles()
            watchConnectivity.requestMetadataUpdate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            print("📱 Received RefreshFileList notification")
            refreshFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("📱 App entering foreground - refreshing files")
            refreshFiles()
            watchConnectivity.requestMetadataUpdate()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(fileURLs: filesToShare)
        }
        .alert("Delete All Files?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllFiles()
            }
        } message: {
            Text("Are you sure you want to delete all \(fileInfos.count) files? This cannot be undone.")
        }
    }

    // MARK: - Helper Functions

    func refreshFiles() {
        // Combine locally synced files with pending files from watch
        let syncedFiles = csvFileManager.getCSVFilesWithMetadata()
        var allFiles = syncedFiles + watchConnectivity.pendingFiles

        // Get set of synced file names for quick lookup
        let syncedFileNames = Set(syncedFiles.map { $0.fileName })

        // Remove files from transferring set if they're now synced
        let completedTransfers = filesCurrentlyTransferring.intersection(syncedFileNames)
        if !completedTransfers.isEmpty {
            print("📱 Completed transfers: \(completedTransfers)")
            filesCurrentlyTransferring.subtract(completedTransfers)
        }

        // Mark files that are currently transferring
        for i in 0..<allFiles.count {
            if filesCurrentlyTransferring.contains(allFiles[i].fileName) {
                allFiles[i].syncState = .transferring
            }
        }

        fileInfos = allFiles
        print("📱 Refreshed file list: \(syncedFiles.count) synced, \(watchConnectivity.pendingFiles.count) pending, \(filesCurrentlyTransferring.count) transferring")
    }

    func formatDataDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a"
        return formatter.string(from: date)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func deleteFiles(at offsets: IndexSet) {
        let sorted = sortedFiles

        for index in offsets {
            let fileInfo = sorted[index]
            do {
                try FileManager.default.removeItem(at: fileInfo.url)
                print("Deleted file: \(fileInfo.fileName)")
            } catch {
                print("Error deleting file: \(error)")
            }
        }

        let urlsToRemove = offsets.map { sorted[$0].url }
        fileInfos.removeAll { fileInfo in
            urlsToRemove.contains(fileInfo.url)
        }
    }

    func deleteAllFiles() {
        // Only delete SYNCED files (not pending files from watch)
        let syncedFiles = fileInfos.filter { $0.syncState == .synced }

        for fileInfo in syncedFiles {
            if FileManager.default.fileExists(atPath: fileInfo.url.path) {
                do {
                    try FileManager.default.removeItem(at: fileInfo.url)
                    print("Deleted file: \(fileInfo.fileName)")
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
        }

        refreshFiles()
        print("Deleted \(syncedFiles.count) synced files from iPhone")
    }

    func exportAndShareLabels() {
        // Export all segments as CSV
        let csv = SegmentManager.shared.exportAllSegmentsAsCSV()

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("activity_labels_\(Date().timeIntervalSince1970).csv")

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            filesToShare = [tempURL]
            showShareSheet = true
            print("📤 Exported labels CSV: \(csv.components(separatedBy: "\n").count - 1) rows")
        } catch {
            print("❌ Error exporting labels: \(error)")
        }
    }

    // MARK: - Subviews

    private var watchSyncControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: {
                    watchConnectivity.requestSyncFromWatch()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Sync from Watch")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!watchConnectivity.isReachable || watchConnectivity.syncInProgress)

                Button(action: {
                    watchConnectivity.requestDeleteSyncedFilesOnWatch()
                }) {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("Delete Synced")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!watchConnectivity.isReachable)
            }

            Button(action: {
                watchConnectivity.requestDeleteAllFilesOnWatch()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete All on Watch")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!watchConnectivity.isReachable)
        }
        .padding(.horizontal)
    }
}
