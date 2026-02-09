//
//  CloudSyncService.swift
//  Andernet Posture
//
//  Monitors CloudKit sync status and exposes observable state
//  for the Settings UI. Uses NSPersistentCloudKitContainer event
//  notifications to track import/export progress.
//

import Foundation
import CloudKit
import CoreData
import os.log
import Combine

private let logger = Logger(subsystem: "dev.andernet.posture", category: "CloudSync")

// MARK: - SyncStatus

/// Simplified sync status for display in Settings.
enum SyncStatus: Sendable {
    case idle
    case syncing
    case succeeded(Date)
    case failed(String)
    case disabled

    var label: String {
        switch self {
        case .idle:          return String(localized: "Waiting")
        case .syncing:       return String(localized: "Syncing…")
        case .succeeded:     return String(localized: "Up to date")
        case .failed(let m): return m
        case .disabled:      return String(localized: "Off")
        }
    }

    var systemImage: String {
        switch self {
        case .idle:      return "clock"
        case .syncing:   return "arrow.triangle.2.circlepath"
        case .succeeded: return "checkmark.icloud.fill"
        case .failed:    return "exclamationmark.icloud.fill"
        case .disabled:  return "icloud.slash"
        }
    }
}

// MARK: - CloudSyncService

@Observable
@MainActor
final class CloudSyncService {
    private(set) var status: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    private var cancellables = Set<AnyCancellable>()

    init() {
        startObservingCloudKitEvents()
    }

    // MARK: - CloudKit Event Monitoring

    private func startObservingCloudKitEvents() {
        // NSPersistentCloudKitContainer posts these notifications for every
        // import/export/setup event. SwiftData's CloudKit integration uses
        // the same underlying container, so we receive them automatically.
        NotificationCenter.default.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
        .store(in: &cancellables)
    }

    nonisolated private func handleCloudKitEvent(_ notification: Notification) {
        // The event is packed in userInfo under the key
        // "NSPersistentCloudKitContainer.eventNotificationUserInfoKey"
        // We use the event's type and endDate to determine status.
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            logger.debug("Received cloud event notification without parseable event.")
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            if event.endDate == nil {
                // Event is in progress
                self.status = .syncing
                logger.info("CloudKit sync started: \(String(describing: event.type))")
            } else if let error = event.error {
                self.status = .failed(error.localizedDescription)
                logger.error("CloudKit sync error: \(error.localizedDescription)")
            } else {
                let now = Date.now
                self.status = .succeeded(now)
                self.lastSyncDate = now
                logger.info("CloudKit sync completed: \(String(describing: event.type))")
            }
        }
    }

    // MARK: - Account Availability

    /// Check whether the user is signed in to iCloud.
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await CKContainer(identifier: "iCloud.dev.andernet.posture")
                .accountStatus()
            let available = status == .available
            if !available {
                logger.warning("iCloud account not available: \(String(describing: status))")
            }
            return available
        } catch {
            logger.error("iCloud account check failed: \(error.localizedDescription)")
            return false
        }
    }
}
