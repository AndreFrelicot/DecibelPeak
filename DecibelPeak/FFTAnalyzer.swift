//
//  FFTAnalyzer.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import Accelerate
import Foundation

final class FFTAnalyzer: @unchecked Sendable {
    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]
    private let lock = NSLock()
    private var realp: [Float]
    private var imagp: [Float]

    init(fftSize: Int = 512) {
        precondition(fftSize > 1 && (fftSize & (fftSize - 1)) == 0, "FFT size must be a power of two greater than 1")
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Unable to create FFT setup")
        }
        self.fftSetup = fftSetup

        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = window

        self.realp = [Float](repeating: 0.0, count: fftSize / 2)
        self.imagp = [Float](repeating: 0.0, count: fftSize / 2)
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func analyze(samples: [Float]) -> [Float] {
        guard samples.count >= fftSize else {
            return Array(repeating: 0.0, count: fftSize / 2)
        }
        
        var windowedInput = [Float](repeating: 0.0, count: fftSize)
        samples.withUnsafeBufferPointer { inputBuffer in
            guard let inputBaseAddress = inputBuffer.baseAddress else { return }
            vDSP_vmul(inputBaseAddress, 1, window, 1, &windowedInput, 1, vDSP_Length(fftSize))
        }
        
        // Convert to split complex format and perform FFT
        return lock.withLock {
            realp.withUnsafeMutableBufferPointer { realBuffer in
                return imagp.withUnsafeMutableBufferPointer { imagBuffer in
                    var output = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)

                    windowedInput.withUnsafeBufferPointer { buffer in
                        buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexBuffer in
                            vDSP_ctoz(complexBuffer, 2, &output, 1, vDSP_Length(fftSize / 2))
                        }
                    }

                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))

                    // Calculate magnitude spectrum
                    var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
                    vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

                    // Convert to dB scale and normalize
                    var dbMagnitudes = [Float](repeating: 0.0, count: fftSize / 2)
                    for i in 0..<magnitudes.count {
                        let magnitude = max(0.000001, magnitudes[i])  // Prevent log(0)
                        dbMagnitudes[i] = 20 * log10(magnitude)
                    }

                    // Normalize and clamp values
                    let maxDB: Float = 0.0
                    let minDB: Float = -60.0

                    for i in 0..<dbMagnitudes.count {
                        dbMagnitudes[i] = max(minDB, min(maxDB, dbMagnitudes[i]))
                        dbMagnitudes[i] = (dbMagnitudes[i] - minDB) / (maxDB - minDB)
                    }

                    return dbMagnitudes
                }
            }
        }
    }
    
    func getFrequencyBands(magnitudes: [Float], sampleRate: Float = 44100.0, bandCount: Int = 32) -> [Float] {
        guard bandCount > 0 else { return [] }
        guard !magnitudes.isEmpty, sampleRate > 0 else {
            return Array(repeating: 0.0, count: bandCount)
        }

        let nyquistFrequency = sampleRate / 2.0
        let frequencyResolution = nyquistFrequency / Float(magnitudes.count)
        guard frequencyResolution > 0 else {
            return Array(repeating: 0.0, count: bandCount)
        }
        
        var bands = [Float](repeating: 0.0, count: bandCount)
        
        // Define frequency bands (logarithmic spacing)
        var frequencies = [Float]()
        let minFreq: Float = 20.0  // 20 Hz
        let maxFreq: Float = 20000.0  // 20 kHz
        let denominator = max(bandCount - 1, 1)
        
        for i in 0..<bandCount {
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)
            let logFreq = logMin + (Float(i) / Float(denominator)) * (logMax - logMin)
            frequencies.append(pow(10, logFreq))
        }
        
        // Map FFT bins to frequency bands
        for (bandIndex, frequency) in frequencies.enumerated() {
            let binIndex = Int(frequency / frequencyResolution)
            if binIndex < magnitudes.count {
                // Average surrounding bins for smoother representation
                let startBin = max(0, binIndex - 1)
                let endBin = min(magnitudes.count - 1, binIndex + 1)
                var sum: Float = 0.0
                var count: Float = 0.0
                
                for bin in startBin...endBin {
                    sum += magnitudes[bin]
                    count += 1.0
                }
                
                bands[bandIndex] = count > 0 ? sum / count : 0.0
            }
        }
        
        return bands
    }
}
