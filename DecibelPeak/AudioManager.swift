//
//  AudioManager.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import AVFoundation
import SwiftUI

struct TimestampedDbValue {
    let value: Double
    let timestamp: TimeInterval
    let appearanceTime: TimeInterval // When the data should start appearing visually
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
    private var waterfallBuffer: [[Float]] = []
    private var waterfallWriteIndex = 0
    private var waterfallUpdateCounter = 0
    private var lastWaterfallBands: [Float] = Array(repeating: 0.0, count: 64)
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var levelTimer: Timer?
    private var dbHistoryTimer: Timer?
    private var currentDb: Float = 50.0
    private var sampleBuffer: [Float] = []
    private let maxSamples = 100
    private let maxWaterfallRows = 80
    private let fftAnalyzer = FFTAnalyzer(fftSize: 1024)
    
    override init() {
        super.init()
        // Initialize circular buffer
        waterfallBuffer = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        // Pre-populate waterfallData with all rows to prevent stretching during startup
        waterfallData = Array(repeating: Array(repeating: 0.0, count: 64), count: maxWaterfallRows)
        // Initialize dbHistory with 100 points (matches maxHistoryPoints in DbCurveView)
        dbHistory = Array(repeating: 0.0, count: 100)
        requestPermission()
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
        try session.setCategory(.record, mode: .measurement)
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
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
                self?.updatePublishedLevel()
            }

            // Start dB history collection timer at 10 FPS (0.1s intervals)
            dbHistoryTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateDbHistory()
            }
            
        } catch {
            print("Error starting audio monitoring: \(error)")
            stopMonitoring()
        }
    }
    
    func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        dbHistoryTimer?.invalidate()
        dbHistoryTimer = nil
        
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
        let calibratedDb = avgPower + 100
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
    
    private func updatePublishedLevel() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.decibelLevel = min(130, Double(self.currentDb))
                self.waveformSamples = self.sampleBuffer
            }
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
