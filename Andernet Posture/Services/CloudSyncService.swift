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

    /// Number of consecutive transient errors — used to decide
    /// whether to stay in "Syncing" or flip to "failed".
    private var consecutiveTransientErrors = 0
    private static let maxTransientRetries = 5

    private var cancellables = Set<AnyCancellable>()

    init() {
        startObservingCloudKitEvents()
    }

    // MARK: - CloudKit Event Monitoring

    private func startObservingCloudKitEvents() {
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
                logger.info("CloudKit sync started: type=\(String(describing: event.type))")
            } else if let error = event.error {
                self.handleSyncError(error, eventType: event.type)
            } else {
                // Success — reset transient counter
                self.consecutiveTransientErrors = 0
                let now = Date.now
                self.status = .succeeded(now)
                self.lastSyncDate = now
                logger.info("CloudKit sync completed: type=\(String(describing: event.type))")
            }
        }
    }

    // MARK: - Error Classification

    /// Classify the error and decide whether to show a user-facing failure
    /// or treat it as transient (the container will retry automatically).
    private func handleSyncError(_ error: Error, eventType: NSPersistentCloudKitContainer.EventType) {
        let nsError = error as NSError
        let code = nsError.code
        let domain = nsError.domain

        // Log full details for debugging
        logger.error("""
        CloudKit sync error — domain=\(domain) code=\(code) \
        type=\(String(describing: eventType)) \
        description=\(nsError.localizedDescription) \
        underlying=\(String(describing: nsError.userInfo[NSUnderlyingErrorKey]))
        """)

        // Determine if this is transient
        let isTransient: Bool
        if domain == CKError.errorDomain {
            isTransient = Self.isTransientCKErrorCode(code)
        } else {
            // CoreData / NSPersistentCloudKitContainer internal errors
            // often wrap transient CK errors in the underlying-error chain
            isTransient = Self.containsTransientCKError(nsError)
        }

        if isTransient {
            consecutiveTransientErrors += 1
            if consecutiveTransientErrors <= Self.maxTransientRetries {
                // Stay in "syncing" — the container retries automatically
                status = .syncing
                logger.info("Transient sync error (\(self.consecutiveTransientErrors)/\(Self.maxTransientRetries)), will retry automatically.")
                return
            }
        }

        // Permanent or too many transient retries — show user-friendly message
        status = .failed(Self.friendlyMessage(domain: domain, code: code))
    }

    /// Whether a CKError code represents a transient/retryable condition.
    private static func isTransientCKErrorCode(_ code: Int) -> Bool {
        switch CKError.Code(rawValue: code) {
        case .partialFailure,
             .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .zoneBusy,
             .requestRateLimited:
            return true
        default:
            return false
        }
    }

    /// Walk the `NSUnderlyingError` chain looking for a transient CKError.
    private static func containsTransientCKError(_ error: NSError) -> Bool {
        var current: NSError? = error
        while let err = current {
            if err.domain == CKError.errorDomain, isTransientCKErrorCode(err.code) {
                return true
            }
            current = err.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    /// Map raw error codes to short, actionable messages.
    private static func friendlyMessage(domain: String, code: Int) -> String {
        if domain == CKError.errorDomain {
            switch CKError.Code(rawValue: code) {
            case .notAuthenticated:
                return String(localized: "Sign in to iCloud in Settings")
            case .networkUnavailable, .networkFailure:
                return String(localized: "No network connection")
            case .quotaExceeded:
                return String(localized: "iCloud storage full")
            case .badContainer, .missingEntitlement:
                return String(localized: "iCloud configuration error")
            case .incompatibleVersion:
                return String(localized: "Update the app to sync")
            case .partialFailure:
                return String(localized: "Sync partially failed — retrying")
            case .serviceUnavailable, .zoneBusy, .requestRateLimited:
                return String(localized: "iCloud busy — will retry")
            default:
                return String(localized: "Sync error (\(code))")
            }
        }
        return String(localized: "Sync error (\(code))")
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
