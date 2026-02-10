//
//  MetricsManager.swift
//  Andernet Posture
//
//  Production performance monitoring using MetricKit
//

import Foundation
import MetricKit
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "Metrics")

/// Collects and reports app performance metrics in production using MetricKit.
/// This helps identify performance issues, crashes, and battery usage in the wild.
@MainActor
final class MetricsManager: NSObject, MXMetricManagerSubscriber {
    
    static let shared = MetricsManager()
    
    private override init() {
        super.init()
        MXMetricManager.shared.add(self)
        logger.info("MetricsManager initialized and subscribed")
    }
    
    deinit {
        MXMetricManager.shared.remove(self)
    }
    
    // MARK: - MXMetricManagerSubscriber
    
    /// Called when new metric payloads are available (typically daily).
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        Task { @MainActor in
            for payload in payloads {
                processMetricPayload(payload)
            }
        }
    }
    
    /// Called when diagnostic payloads are available (crashes, hangs, etc.).
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Task { @MainActor in
            for payload in payloads {
                processDiagnosticPayload(payload)
            }
        }
    }
    
    // MARK: - Processing
    
    private func processMetricPayload(_ payload: MXMetricPayload) {
        logger.info("Received metric payload for time range: \(payload.timeStampBegin) to \(payload.timeStampEnd)")
        
        // CPU Metrics
        if let cpuMetrics = payload.cpuMetrics {
            let cumulativeTime = cpuMetrics.cumulativeCPUTime.converted(to: .seconds).value
            logger.info("CPU Usage: \(cumulativeTime, format: .fixed(precision: 2))s cumulative")
        }
        
        // Memory Metrics
        if let memoryMetrics = payload.memoryMetrics {
            let peakMemory = memoryMetrics.peakMemoryUsage.converted(to: .megabytes).value
            let averageMemory = memoryMetrics.averageSuspendedMemory?.converted(to: .megabytes).value ?? 0
            logger.info("Memory - Peak: \(peakMemory, format: .fixed(precision: 1))MB, Avg Suspended: \(averageMemory, format: .fixed(precision: 1))MB")
        }
        
        // Display Metrics (FPS, Hitches)
        if let displayMetrics = payload.displayMetrics {
            logger.info("Display - Average Pixels Per Second: \(displayMetrics.averagePixelLuminance.averageMeasurement)")
        }
        
        // Animation Metrics (SwiftUI/UIKit animations)
        if let animationMetrics = payload.animationMetrics {
            let scrollHitchTime = animationMetrics.scrollHitchTimeRatio.averageMeasurement
            logger.info("Animation - Scroll Hitch Ratio: \(scrollHitchTime)")
        }
        
        // Application Launch Metrics
        if let launchMetrics = payload.applicationLaunchMetrics {
            let avgResumeTime = launchMetrics.histogrammedApplicationResumeTime.averageMeasurement.converted(to: .milliseconds).value
            logger.info("Launch - Average Resume Time: \(avgResumeTime, format: .fixed(precision: 1))ms")
        }
        
        // Application Responsiveness (hangs)
        if let responsivenessMetrics = payload.applicationResponsivenessMetrics {
            let hangTime = responsivenessMetrics.histogrammedApplicationHangTime.averageMeasurement.converted(to: .milliseconds).value
            logger.warning("Responsiveness - Average Hang Time: \(hangTime, format: .fixed(precision: 1))ms")
        }
        
        // Network Transfer Metrics
        if let networkMetrics = payload.networkTransferMetrics {
            let cellularDown = networkMetrics.cumulativeCellularDownload.converted(to: .megabytes).value
            let wifiDown = networkMetrics.cumulativeWifiDownload.converted(to: .megabytes).value
            logger.info("Network - Cellular: \(cellularDown, format: .fixed(precision: 2))MB, WiFi: \(wifiDown, format: .fixed(precision: 2))MB")
        }
        
        // Battery & Power Metrics
        if let cellularConditionMetrics = payload.cellularConditionMetrics {
            logger.info("Cellular Condition - Good Coverage Percentage: \(cellularConditionMetrics.cellConditionTime.histogramNumBuckets)")
        }
        
        // TODO: Send to your analytics backend
        // sendToAnalyticsBackend(payload)
    }
    
    private func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        logger.error("Received diagnostic payload for time range: \(payload.timeStampBegin) to \(payload.timeStampEnd)")
        
        // Crash Diagnostics
        if let crashDiagnostics = payload.crashDiagnostics {
            for crash in crashDiagnostics {
                logger.error("Crash detected - Signal: \(crash.signal?.rawValue ?? 0), Exception: \(crash.exceptionType?.rawValue ?? 0)")
                
                // Get crash metadata
                if let callStack = crash.callStackTree {
                    logger.error("Call stack available: \(callStack.jsonRepresentation().count) bytes")
                }
                
                // TODO: Send crash reports to your crash reporting service
                // sendCrashReport(crash)
            }
        }
        
        // Hang Diagnostics
        if let hangDiagnostics = payload.hangDiagnostics {
            for hang in hangDiagnostics {
                let duration = hang.hangDuration.converted(to: .seconds).value
                logger.warning("Hang detected - Duration: \(duration, format: .fixed(precision: 2))s")
                
                // TODO: Investigate hangs - often caused by main thread blocking
            }
        }
        
        // CPU Exception Diagnostics (high CPU usage)
        if let cpuExceptions = payload.cpuExceptionDiagnostics {
            for exception in cpuExceptions {
                let totalTime = exception.totalCPUTime.converted(to: .seconds).value
                logger.warning("CPU Exception - Total Time: \(totalTime, format: .fixed(precision: 2))s")
            }
        }
        
        // Disk Write Exception Diagnostics
        if let diskExceptions = payload.diskWriteExceptionDiagnostics {
            for exception in diskExceptions {
                let totalWrites = exception.totalWritesCaused.converted(to: .megabytes).value
                logger.warning("Disk Write Exception - Total: \(totalWrites, format: .fixed(precision: 2))MB")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Simulate a diagnostic payload (for testing in development).
    /// Note: This will only work in TestFlight or production builds.
    func simulateDiagnosticPayload() {
        #if DEBUG
        logger.debug("Note: MetricKit diagnostic simulation only works in TestFlight/production")
        #endif
        
        // In production, you can request a diagnostic payload
        // MXMetricManager.shared.deliverDiagnosticPayload()
    }
    
    /// Export metrics as JSON for external analysis.
    private func exportMetricsJSON(_ payload: MXMetricPayload) -> Data? {
        return payload.jsonRepresentation()
    }
    
    /// Send metrics to your analytics backend (implement as needed).
    private func sendToAnalyticsBackend(_ payload: MXMetricPayload) {
        // Example: Send to your server
        // if let jsonData = exportMetricsJSON(payload) {
        //     // POST to your analytics endpoint
        // }
    }
}

// MARK: - App Integration

extension Andernet_PostureApp {
    /// Initialize MetricKit monitoring when the app starts.
    func setupMetricsMonitoring() {
        #if !DEBUG
        // Only enable in TestFlight and production builds
        _ = MetricsManager.shared
        logger.info("MetricKit monitoring enabled")
        #endif
    }
}
