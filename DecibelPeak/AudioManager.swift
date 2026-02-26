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

class AudioManager: NSObject, ObservableObject {
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

    // Calibration settings
    @Published var calibrationOffset: Double = 0.0
    @Published var showCalibrationOverlay: Bool = false
    @Published var tempCalibrationOffset: Double = 0.0

    // Calibration constants
    static let minCalibrationOffset: Double = -20.0
    static let maxCalibrationOffset: Double = 20.0
    static let calibrationStep: Double = 0.5

    private static let calibrationKey = "calibrationOffset"

    private var waterfallBuffer: [[Float]] = []
    private var waterfallWriteIndex = 0
    private var waterfallUpdateCounter = 0
    private var lastWaterfallBands: [Float] = Array(repeating: 0.0, count: 64)
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var displayLink: CADisplayLink?
    private var lastDbHistoryUpdateTime: CFTimeInterval = 0
    private var currentDb: Float = 50.0
    private var sampleBuffer: [Float] = []
    private let maxSamples = 100
    private let maxWaterfallRows = 80
    private let fftAnalyzer = FFTAnalyzer(fftSize: 1024)
    private var peakBuffer: [DbPeakDataPoint] = []
    private var sessionPeakDb: Double = 0.0
    private var sessionPeakTime: Date = Date()
    private var frozenPeakSnapshot: [DbPeakDataPoint]? = nil
    
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
        requestPermission()
    }

    // MARK: - Calibration Methods

    func showCalibration() {
        tempCalibrationOffset = calibrationOffset
        showCalibrationOverlay = true
    }

    func hideCalibration() {
        showCalibrationOverlay = false
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
    }

    func saveCalibration() {
        calibrationOffset = tempCalibrationOffset
        UserDefaults.standard.set(calibrationOffset, forKey: AudioManager.calibrationKey)
        showCalibrationOverlay = false
    }

    func cancelCalibration() {
        tempCalibrationOffset = calibrationOffset
        showCalibrationOverlay = false
    }
    
    func requestPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted

                // Auto-start monitoring when permissions are granted
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.startMonitoring()
                    }
                }
            }
        }
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
        guard permissionGranted else { return }
        
        do {
            try configureAudioSession()
            
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            inputNode = audioEngine.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            
            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
            lastDbHistoryUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(updateDisplay(_:)))
            displayLink?.add(to: .main, forMode: .common)
            
        } catch {
            print("Error starting audio monitoring: \(error)")
            stopMonitoring()
        }
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        
        inputNode?.removeTap(onBus: 0)
        
        audioEngine?.stop()
        audioEngine = nil
        
        isRecording = false
        
        // Reset values when stopping
        DispatchQueue.main.async {
            self.decibelLevel = 0.0
            self.waveformSamples = Array(repeating: 0.0, count: self.maxSamples)
            self.frequencyBands = Array(repeating: 0.0, count: 64)
            self.waterfallData = Array(repeating: Array(repeating: 0.0, count: 64), count: self.maxWaterfallRows)
            self.waterfallBuffer = Array(repeating: Array(repeating: 0.0, count: 64), count: self.maxWaterfallRows)
            self.waterfallWriteIndex = 0
            self.waterfallUpdateCounter = 0
            self.lastWaterfallBands = Array(repeating: 0.0, count: 64)
            self.currentDb = 0.0
            self.sampleBuffer = Array(repeating: 0.0, count: self.maxSamples)
            self.dbHistory = Array(repeating: 0.0, count: 100)
            self.timestampedDbHistory = []
            self.peakBuffer = []
            self.sessionPeakDb = 0.0
            self.sessionPeakTime = Date()
            self.frozenPeakSnapshot = nil
            self.dbPeakData = []
            self.dbPeakValue = 0.0
            self.dbPeakTime = Date()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Error deactivating audio session: \(error)")
            }
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        // Calculate RMS for decibel level
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(0.00001, rms))
        // Base calibration (100) + user calibration offset (use temp offset for live preview)
        let activeOffset = showCalibrationOverlay ? tempCalibrationOffset : calibrationOffset
        let calibratedDb = avgPower + 100 + Float(activeOffset)
        currentDb = currentDb * 0.8 + calibratedDb * 0.2
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
        
        sampleBuffer = newSamples
        
        // Perform FFT analysis
        let fftMagnitudes = fftAnalyzer.analyze(samples: channelDataArray)
        let bands = fftAnalyzer.getFrequencyBands(magnitudes: fftMagnitudes, bandCount: 64)
        
        // Store FFT data for publishing
        DispatchQueue.main.async {
            self.frequencyBands = bands

            // Throttle waterfall updates to 15 FPS (every 2nd frame)
            self.waterfallUpdateCounter += 1
            if self.waterfallUpdateCounter >= 2 {
                self.waterfallUpdateCounter = 0
                self.updateWaterfallData(with: bands)
            }
        }
    }
    
    @objc private func updateDisplay(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.targetTimestamp
        
        // Update fast visualizations (Level & Waveform) at display refresh rate for high FPS
        // using interactiveSpring for highly responsive yet smooth rendering
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.8)) {
            self.decibelLevel = min(130, Double(self.currentDb))
            self.waveformSamples = self.sampleBuffer
        }
        
        // Throttle dB history collection to 10 FPS (0.1s intervals) to prevent accelerated scrolling
        if currentTime - lastDbHistoryUpdateTime >= 0.1 {
            lastDbHistoryUpdateTime = currentTime
            updateDbHistory()
        }
    }

    private func updateWaterfallData(with bands: [Float]) {
        // Apply smoothing to reduce sudden jumps
        let smoothingFactor: Float = 0.3
        var smoothedBands: [Float] = []
        for i in 0..<bands.count {
            let smoothed = lastWaterfallBands[i] * (1.0 - smoothingFactor) + bands[i] * smoothingFactor
            smoothedBands.append(smoothed)
        }
        lastWaterfallBands = smoothedBands

        // Update circular buffer
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

        let initialCount = timestampedDbHistory.count
        timestampedDbHistory.removeAll { $0.timestamp < cutoffTime }
        let finalCount = timestampedDbHistory.count

        // Quietly cull old data points to maintain performance
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
