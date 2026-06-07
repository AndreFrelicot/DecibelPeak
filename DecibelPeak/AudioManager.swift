//
//  AudioManager.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import AVFoundation
import SwiftUI
import UIKit
import AudioToolbox

struct TimestampedDbValue {
    let value: Double
    let timestamp: TimeInterval
    let appearanceTime: TimeInterval // When the data should start appearing visually
}

struct DbPeakDataPoint {
    let value: Double
    let time: Date
}

private final class AudioSnapshotStore: @unchecked Sendable {
    private let lock = NSLock()
    private var currentDb: Float = 50.0
    private var sampleBuffer: [Float]
    private var activeCalibrationOffset: Float = 0.0
    private var activeGeneration = 0

    init(maxSamples: Int) {
        sampleBuffer = Array(repeating: 0.0, count: maxSamples)
    }

    func setCalibrationOffset(_ offset: Double) {
        lock.withLock {
            activeCalibrationOffset = Float(offset)
        }
    }

    func setGeneration(_ generation: Int) {
        lock.withLock {
            activeGeneration = generation
        }
    }

    func calibrationOffset(for generation: Int) -> Float? {
        lock.withLock {
            generation == activeGeneration ? activeCalibrationOffset : nil
        }
    }

    func update(calibratedDb: Float, samples: [Float], generation: Int) -> Bool {
        lock.withLock {
            guard generation == activeGeneration else { return false }
            currentDb = currentDb * 0.8 + calibratedDb * 0.2
            sampleBuffer = samples
            return true
        }
    }

    func snapshot() -> (db: Float, samples: [Float]) {
        lock.withLock {
            (currentDb, sampleBuffer)
        }
    }

    func reset(maxSamples: Int, generation: Int) {
        lock.withLock {
            activeGeneration = generation
            currentDb = 0.0
            sampleBuffer = Array(repeating: 0.0, count: maxSamples)
        }
    }
}

private final class DisplayLinkTarget {
    weak var audioManager: AudioManager?

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    @objc func update(_ displayLink: CADisplayLink) {
        audioManager?.updateDisplay(displayLink)
    }
}

final class AudioManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var decibelLevel: Double = 50.0
    @Published var isRecording: Bool = false
    @Published var permissionGranted: Bool = false
    @Published var waveformSamples: [Float] = Array(repeating: 0.0, count: 100)
    @Published var frequencyBands: [Float] = Array(repeating: 0.0, count: 64)
    @Published var waterfallData: [[Float]] = []
    @Published var selectedVisualization: Int = 0
    @Published var dbHistory: [Double] = []
    @Published var timestampedDbHistory: [TimestampedDbValue] = []
    @Published var dbPeakData: [DbPeakDataPoint] = []
    @Published var dbPeakValue: Double = 0.0
    @Published var dbPeakTime: Date = Date()
    @Published var sessionAverageDb: Double? = nil

    // Calibration settings
    @Published var calibrationOffset: Double = 0.0
    @Published var showCalibrationOverlay: Bool = false
    @Published var tempCalibrationOffset: Double = 0.0

    // Calibration constants
    static let minCalibrationOffset: Double = -20.0
    static let maxCalibrationOffset: Double = 20.0
    static let calibrationStep: Double = 0.5

    private static let calibrationKey = "calibrationOffset"
    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCInjectBundleInto"] != nil
            || arguments.contains { $0.hasSuffix(".xctest") || $0.contains("XCTest") }
            || NSClassFromString("XCTest.XCTestCase") != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private var waterfallBuffer: [[Float]] = []
    private var waterfallWriteIndex = 0
    private var waterfallUpdateCounter = 0
    private var lastWaterfallBands: [Float] = Array(repeating: 0.0, count: 64)
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: DisplayLinkTarget?
    private var pendingSessionDeactivation: DispatchWorkItem?
    private var pendingRouteRestart: DispatchWorkItem?
    private var notificationObservers: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption = false
    private var shouldRestartOnForeground = false
    private var isSceneActive = false
    private var routeRestartGeneration = 0
    private var monitoringGeneration = 0
    private var lastDbHistoryUpdateTime: CFTimeInterval = 0
    private let maxSamples = 100
    private let maxWaterfallRows = 80
    private lazy var audioSnapshotStore = AudioSnapshotStore(maxSamples: maxSamples)
    private let fftAnalyzer = FFTAnalyzer(fftSize: 1024)
    private var peakBuffer: [DbPeakDataPoint] = []
    private var sessionPeakDb: Double = 0.0
    private var sessionPeakTime: Date = Date()
    private var frozenPeakSnapshot: [DbPeakDataPoint]? = nil
    private var sessionAveragePowerSum: Double = 0.0
    private var sessionAverageSampleCount: Int = 0
    
    override init() {
        super.init()
        // Initialize circular buffer
        waterfallBuffer = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        // Pre-populate waterfallData with all rows to prevent stretching during startup
        waterfallData = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        // Initialize dbHistory with 100 points (matches maxHistoryPoints in DbCurveView)
        dbHistory = Array(repeating: 0.0, count: 100)
        // Load saved calibration offset
        calibrationOffset = UserDefaults.standard.double(forKey: AudioManager.calibrationKey)
        updateActiveCalibrationOffset()
        registerAudioSessionObservers()
        if !AudioManager.isRunningTests {
            requestPermission()
        }
    }

    // MARK: - Calibration Methods

    func showCalibration() {
        tempCalibrationOffset = calibrationOffset
        showCalibrationOverlay = true
        updateActiveCalibrationOffset()
    }

    func hideCalibration() {
        showCalibrationOverlay = false
        updateActiveCalibrationOffset()
    }

    func setTempCalibrationOffset(_ offset: Double) {
        // Round to nearest step
        var rounded = (offset / AudioManager.calibrationStep).rounded() * AudioManager.calibrationStep

        // Snap to 0 when entering the -0.5 to +0.5 range
        let wasNotZero = tempCalibrationOffset != 0.0
        if rounded > -0.5 && rounded < 0.5 {
            rounded = 0.0
        }

        let newValue = rounded.clamped(to: AudioManager.minCalibrationOffset...AudioManager.maxCalibrationOffset)

        // Play haptic feedback when snapping to 0
        if wasNotZero && newValue == 0.0 {
            // Use AudioServicesPlaySystemSound for reliable haptic feedback
            // 1519 = "Peek" haptic (gentle tap)
            AudioServicesPlaySystemSound(1519)
        }

        tempCalibrationOffset = newValue
        updateActiveCalibrationOffset()
    }

    func saveCalibration() {
        calibrationOffset = tempCalibrationOffset
        UserDefaults.standard.set(calibrationOffset, forKey: AudioManager.calibrationKey)
        showCalibrationOverlay = false
        updateActiveCalibrationOffset()
    }

    func cancelCalibration() {
        tempCalibrationOffset = calibrationOffset
        showCalibrationOverlay = false
        updateActiveCalibrationOffset()
    }
    
    func requestPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let audioManager = self else { return }
            DispatchQueue.main.async { [audioManager] in
                audioManager.permissionGranted = granted

                // Auto-start monitoring when permissions are granted
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak audioManager] in
                        audioManager?.startMonitoring()
                    }
                }
            }
        }
    }

    func refreshPermissionState() {
        permissionGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    private func updateActiveCalibrationOffset() {
        let offset = showCalibrationOverlay ? tempCalibrationOffset : calibrationOffset
        audioSnapshotStore.setCalibrationOffset(offset)
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            isSceneActive = true
            refreshPermissionState()
            guard shouldRestartOnForeground else { return }
            shouldRestartOnForeground = false
            guard permissionGranted else { return }
            startMonitoring()
        case .background:
            shouldRestartOnForeground = isRecording || shouldResumeAfterInterruption || pendingRouteRestart != nil
            isSceneActive = false
            cancelPendingRouteRestart()
            if isRecording {
                stopMonitoring(resetAutoResumeFlags: false)
            }
        case .inactive:
            if pendingRouteRestart != nil {
                shouldRestartOnForeground = true
            }
            isSceneActive = false
            cancelPendingRouteRestart()
            break
        @unknown default:
            break
        }
    }

    private func registerAudioSessionObservers() {
        let session = AVAudioSession.sharedInstance()
        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
        )
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isRecording
            if isRecording {
                stopMonitoring(resetAutoResumeFlags: false)
            }
        case .ended:
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard shouldResumeAfterInterruption, permissionGranted, options.contains(.shouldResume) else {
                shouldResumeAfterInterruption = false
                return
            }
            shouldResumeAfterInterruption = false
            guard isSceneActive else {
                shouldRestartOnForeground = true
                return
            }
            startMonitoring()
        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(_ notification: Notification) {
        guard isRecording else { return }
        guard
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            restartMonitoringAfterRouteChange()
        default:
            break
        }
    }

    private func restartMonitoringAfterRouteChange() {
        guard permissionGranted, isSceneActive else { return }
        cancelPendingRouteRestart()
        stopMonitoring(resetAutoResumeFlags: false)

        routeRestartGeneration += 1
        let restartGeneration = routeRestartGeneration
        let routeRestart = DispatchWorkItem { [weak self] in
            guard
                let self,
                self.routeRestartGeneration == restartGeneration,
                self.permissionGranted,
                self.isSceneActive,
                !self.isRecording,
                self.audioEngine == nil
            else {
                return
            }

            self.pendingRouteRestart = nil
            self.startMonitoring()
        }
        pendingRouteRestart = routeRestart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: routeRestart)
    }

    private func cancelPendingRouteRestart() {
        routeRestartGeneration += 1
        pendingRouteRestart?.cancel()
        pendingRouteRestart = nil
    }
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Use .playAndRecord to allow system sounds (haptics) while recording
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
        // Allow haptic feedback during audio recording (iOS 13+)
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setPreferredSampleRate(44100.0)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
    }
    
    func startMonitoring() {
        guard permissionGranted, isSceneActive else { return }
        cancelPendingRouteRestart()
        guard !isRecording, audioEngine == nil else { return }
        pendingSessionDeactivation?.cancel()
        pendingSessionDeactivation = nil
        monitoringGeneration += 1
        let generation = monitoringGeneration
        audioSnapshotStore.setGeneration(generation)
        
        do {
            try configureAudioSession()
            
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            inputNode = audioEngine.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            let maxSamples = maxSamples
            let snapshotStore = audioSnapshotStore
            
            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(
                    buffer,
                    maxSamples: maxSamples,
                    snapshotStore: snapshotStore,
                    generation: generation
                )
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            shouldResumeAfterInterruption = false
            
            lastDbHistoryUpdateTime = CACurrentMediaTime()
            displayLinkTarget = DisplayLinkTarget(audioManager: self)
            displayLink = CADisplayLink(target: displayLinkTarget!, selector: #selector(DisplayLinkTarget.update(_:)))
            displayLink?.add(to: .main, forMode: .common)
            
        } catch {
            print("Error starting audio monitoring: \(error)")
            stopMonitoring()
        }
    }
    
    func stopMonitoring() {
        stopMonitoring(resetAutoResumeFlags: true)
    }

    private func stopMonitoring(resetAutoResumeFlags: Bool) {
        if resetAutoResumeFlags {
            shouldResumeAfterInterruption = false
            shouldRestartOnForeground = false
            cancelPendingRouteRestart()
        }

        monitoringGeneration += 1
        let generation = monitoringGeneration

        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        
        inputNode?.removeTap(onBus: 0)
        inputNode = nil
        
        audioEngine?.stop()
        audioEngine = nil
        
        isRecording = false
        
        audioSnapshotStore.reset(maxSamples: maxSamples, generation: generation)

        // Reset values when stopping
        decibelLevel = 0.0
        waveformSamples = Array(repeating: 0.0, count: maxSamples)
        frequencyBands = Array(repeating: 0.0, count: 64)
        waterfallData = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        waterfallBuffer = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        waterfallWriteIndex = 0
        waterfallUpdateCounter = 0
        lastWaterfallBands = Array(repeating: 0.0, count: 64)
        dbHistory = Array(repeating: 0.0, count: 100)
        timestampedDbHistory = []
        peakBuffer = []
        sessionPeakDb = 0.0
        sessionPeakTime = Date()
        frozenPeakSnapshot = nil
        dbPeakData = []
        dbPeakValue = 0.0
        dbPeakTime = Date()
        sessionAveragePowerSum = 0.0
        sessionAverageSampleCount = 0
        sessionAverageDb = nil
        
        let deactivation = DispatchWorkItem { [weak self] in
            guard let self, self.monitoringGeneration == generation, !self.isRecording else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session: \(error)")
            }
        }
        pendingSessionDeactivation = deactivation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: deactivation)
    }
    
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        maxSamples: Int,
        snapshotStore: AudioSnapshotStore,
        generation: Int
    ) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        guard let calibrationOffset = snapshotStore.calibrationOffset(for: generation) else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: frameLength))
        
        // Calculate RMS for decibel level
        let sumOfSquares = channelDataArray.reduce(Float(0.0)) { $0 + ($1 * $1) }
        let rms = sqrt(sumOfSquares / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(0.00001, rms))
        // Base calibration (100) + user calibration offset (use temp offset for live preview)
        let calibratedDb = AudioManager.sanitizedDecibel(avgPower + 100 + calibrationOffset)
        //currentDb = Float.random(in: 90...140)
        
        // Update waveform samples
        let downsampleFactor = max(1, channelDataArray.count / maxSamples)
        var newSamples: [Float] = []
        
        for i in stride(from: 0, to: channelDataArray.count, by: downsampleFactor) {
            if i < channelDataArray.count {
                let sample = channelDataArray[i]
                newSamples.append(sample)
            }
        }
        
        // Trim to maxSamples
        if newSamples.count > maxSamples {
            newSamples = Array(newSamples.suffix(maxSamples))
        }
        
        // Pad with zeros if needed
        while newSamples.count < maxSamples {
            newSamples.insert(0.0, at: 0)
        }
        
        guard snapshotStore.update(calibratedDb: calibratedDb, samples: newSamples, generation: generation) else { return }
        
        // Perform FFT analysis
        let fftMagnitudes = fftAnalyzer.analyze(samples: channelDataArray)
        let bands = fftAnalyzer.getFrequencyBands(magnitudes: fftMagnitudes, bandCount: 64)
        
        // Store FFT data for publishing
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.monitoringGeneration == generation, self.isRecording else { return }
            self.frequencyBands = bands

            // Throttle waterfall updates to 15 FPS (every 2nd frame)
            self.waterfallUpdateCounter += 1
            if self.waterfallUpdateCounter >= 2 {
                self.waterfallUpdateCounter = 0
                self.updateWaterfallData(with: bands)
            }
        }
    }
    
    fileprivate func updateDisplay(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.targetTimestamp
        let snapshot = audioSnapshotStore.snapshot()
        
        // Update fast visualizations (Level & Waveform) at display refresh rate for high FPS
        // using interactiveSpring for highly responsive yet smooth rendering
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.8)) {
            self.decibelLevel = Double(snapshot.db)
            self.waveformSamples = snapshot.samples
        }
        
        // Throttle dB history collection to 10 FPS (0.1s intervals) to prevent accelerated scrolling
        if currentTime - lastDbHistoryUpdateTime >= 0.1 {
            lastDbHistoryUpdateTime = currentTime
            updateDbHistory()
        }
    }

    private func updateWaterfallData(with bands: [Float]) {
        guard !bands.isEmpty else { return }

        // Apply smoothing to reduce sudden jumps
        let smoothingFactor: Float = 0.3
        let previousBands = lastWaterfallBands.count == bands.count
            ? lastWaterfallBands
            : Array(repeating: 0.0, count: bands.count)
        var smoothedBands: [Float] = []
        for i in bands.indices {
            let smoothed = previousBands[i] * (1.0 - smoothingFactor) + bands[i] * smoothingFactor
            smoothedBands.append(smoothed)
        }
        lastWaterfallBands = smoothedBands

        // Update circular buffer
        if waterfallBuffer[waterfallWriteIndex].count != smoothedBands.count {
            waterfallBuffer = Array(repeating: Array(repeating: 0.0, count: smoothedBands.count), count: maxWaterfallRows)
            waterfallWriteIndex = 0
        }
        waterfallBuffer[waterfallWriteIndex] = smoothedBands
        waterfallWriteIndex = (waterfallWriteIndex + 1) % maxWaterfallRows

        // Reconstruct published array in correct order (newest first)
        // Always include ALL rows to maintain consistent count
        var orderedData: [[Float]] = []
        for i in 0..<maxWaterfallRows {
            let index = (waterfallWriteIndex - 1 - i + maxWaterfallRows) % maxWaterfallRows
            let row = waterfallBuffer[index]
            orderedData.append(row) // Include all rows, even empty ones
        }
        waterfallData = orderedData
    }

    static func sanitizedDecibel(_ value: Float) -> Float {
        guard value.isFinite else { return 0.0 }
        return min(130.0, max(0.0, value))
    }

    static func linearPower(forDecibel decibel: Double) -> Double? {
        guard decibel.isFinite else { return nil }
        let power = pow(10.0, decibel / 10.0)
        guard power.isFinite, power > 0 else { return nil }
        return power
    }

    static func equivalentDecibelLevel(linearPowerSum: Double, sampleCount: Int) -> Double? {
        guard sampleCount > 0, linearPowerSum.isFinite, linearPowerSum > 0 else { return nil }
        let averagePower = linearPowerSum / Double(sampleCount)
        guard averagePower.isFinite, averagePower > 0 else { return nil }
        return 10.0 * log10(averagePower)
    }

    private func updateSessionAverage(with decibel: Double) {
        guard let power = Self.linearPower(forDecibel: decibel) else { return }
        sessionAveragePowerSum += power
        sessionAverageSampleCount += 1
        sessionAverageDb = Self.equivalentDecibelLevel(
            linearPowerSum: sessionAveragePowerSum,
            sampleCount: sessionAverageSampleCount
        )
    }

    private func updateDbHistory() {
        // Add new timestamped data point
        let currentTime = CACurrentMediaTime()
        let appearanceDelay: TimeInterval = 0.075 // 75ms delay for smooth appearance
        let newPoint = TimestampedDbValue(
            value: decibelLevel,
            timestamp: currentTime,
            appearanceTime: currentTime + appearanceDelay
        )
        timestampedDbHistory.append(newPoint)

        // Data point will smoothly appear after delay

        // Keep legacy dbHistory for compatibility (may be used elsewhere)
        let maxHistoryPoints = 100
        if dbHistory.count >= maxHistoryPoints {
            dbHistory.removeFirst()
        }
        dbHistory.append(decibelLevel)
        updateSessionAverage(with: decibelLevel)

        // Cull old timestamped data points that are no longer visible
        cullInvisibleDataPoints(currentTime: currentTime)

        // Peak tracking for dB Peak view
        let now = Date()
        let peakPoint = DbPeakDataPoint(value: decibelLevel, time: now)
        peakBuffer.append(peakPoint)

        // Trim rolling buffer to last 65 seconds (enough for 30s before + 30s after peak)
        let bufferCutoff = now.addingTimeInterval(-65)
        peakBuffer.removeAll { $0.time < bufferCutoff }

        // Check for new peak
        if decibelLevel > sessionPeakDb {
            sessionPeakDb = decibelLevel
            sessionPeakTime = now
            frozenPeakSnapshot = nil  // new peak found, unfreeze to capture new window
        }

        // Freeze snapshot once we have 30 seconds of data after the peak
        let timeSincePeak = now.timeIntervalSince(sessionPeakTime)
        if frozenPeakSnapshot == nil && timeSincePeak >= 30.0 {
            let windowStart = sessionPeakTime.addingTimeInterval(-30)
            let windowEnd = sessionPeakTime.addingTimeInterval(30)
            frozenPeakSnapshot = peakBuffer.filter { $0.time >= windowStart && $0.time <= windowEnd }
        }

        // Publish: use frozen snapshot if available, otherwise show live data
        if let frozen = frozenPeakSnapshot {
            dbPeakData = frozen
        } else {
            let windowStart = sessionPeakTime.addingTimeInterval(-30)
            let windowEnd = sessionPeakTime.addingTimeInterval(30)
            dbPeakData = peakBuffer.filter { $0.time >= windowStart && $0.time <= windowEnd }
        }
        dbPeakValue = sessionPeakDb
        dbPeakTime = sessionPeakTime
    }

    private func cullInvisibleDataPoints(currentTime: TimeInterval) {
        // Remove data points that are too old to be visible (beyond left edge with buffer)
        // Account for offscreen start positioning: 10s visible window + 1s buffer + offscreen area
        let timeWindow: TimeInterval = 10.0
        let bufferTime: TimeInterval = 1.5 // Extra buffer for offscreen positioning
        let visibleTimespan = timeWindow + bufferTime
        let cutoffTime = currentTime - visibleTimespan

        timestampedDbHistory.removeAll { $0.timestamp < cutoffTime }

        // Quietly cull old data points to maintain performance
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        pendingSessionDeactivation?.cancel()
        pendingRouteRestart?.cancel()
        displayLink?.invalidate()
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
