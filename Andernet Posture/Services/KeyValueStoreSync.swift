//
//  KeyValueStoreSync.swift
//  Andernet Posture
//
//  Bridges NSUbiquitousKeyValueStore ↔ @AppStorage for lightweight
//  user preferences that should sync across devices (demographics).
//  Device-local prefs (haptics, overlay, sampling rate) stay in UserDefaults only.
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "KVSync")

/// Keys synced to iCloud Key-Value Store.
enum SyncedPreferenceKey: String, CaseIterable {
    case userAge    = "userAge"
    case userSex    = "userSex"
}

@MainActor
final class KeyValueStoreSync: ObservableObject {

    static let shared = KeyValueStoreSync()

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private init() {
        startObserving()
        // Force an initial pull from iCloud
        kvs.synchronize()
    }

    // MARK: - Observe iCloud → Local

    private func startObserving() {
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] notification in
            self?.handleExternalChange(notification)
        }
        .store(in: &cancellables)
    }

    private func handleExternalChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Pull changed keys from iCloud → UserDefaults
            if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                for key in changedKeys {
                    if let syncKey = SyncedPreferenceKey(rawValue: key) {
                        pullFromCloud(syncKey)
                    }
                }
            }
            logger.info("Pulled preferences from iCloud (reason: \(reason))")

        case NSUbiquitousKeyValueStoreAccountChange:
            // Account changed — pull everything
            for key in SyncedPreferenceKey.allCases {
                pullFromCloud(key)
            }
            logger.info("iCloud account changed — refreshed all synced preferences")

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logger.warning("iCloud KVS quota exceeded")

        default:
            break
        }
    }

    // MARK: - Push Local → iCloud

    /// Call after the user changes a synced preference.
    func push(_ key: SyncedPreferenceKey) {
        switch key {
        case .userAge:
            let value = defaults.integer(forKey: key.rawValue)
            kvs.set(value, forKey: key.rawValue)
        case .userSex:
            let value = defaults.string(forKey: key.rawValue) ?? "notSet"
            kvs.set(value, forKey: key.rawValue)
        }
        kvs.synchronize()
        logger.debug("Pushed \(key.rawValue) to iCloud KVS")
    }

    /// Push all synced keys to iCloud (e.g., on first launch after enabling sync).
    func pushAll() {
        for key in SyncedPreferenceKey.allCases {
            push(key)
        }
    }

    // MARK: - Pull iCloud → Local

    private func pullFromCloud(_ key: SyncedPreferenceKey) {
        switch key {
        case .userAge:
            let cloudValue = kvs.object(forKey: key.rawValue) as? Int
            if let cloudValue {
                defaults.set(cloudValue, forKey: key.rawValue)
                logger.debug("Pulled userAge = \(cloudValue) from iCloud")
            }
        case .userSex:
            let cloudValue = kvs.string(forKey: key.rawValue)
            if let cloudValue {
                defaults.set(cloudValue, forKey: key.rawValue)
                logger.debug("Pulled userSex = \(cloudValue) from iCloud")
            }
        }
    }
}
