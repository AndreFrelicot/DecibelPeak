//
//  DecibelPeakTests.swift
//  DecibelPeakTests
//
//  Created by André Frélicot on 12/09/2025.
//

import Testing
@testable import DecibelPeak

struct DecibelPeakTests {

    @Test func sanitizedDecibelClampsInvalidAndOutOfRangeValues() {
        #expect(AudioManager.sanitizedDecibel(-10.0) == 0.0)
        #expect(AudioManager.sanitizedDecibel(.nan) == 0.0)
        #expect(AudioManager.sanitizedDecibel(.infinity) == 0.0)
        #expect(AudioManager.sanitizedDecibel(75.0) == 75.0)
        #expect(AudioManager.sanitizedDecibel(160.0) == 130.0)
    }

    @Test func equivalentDecibelLevelUsesEnergyAverage() {
        let powerSum = AudioManager.linearPower(forDecibel: 60.0)! + AudioManager.linearPower(forDecibel: 70.0)!
        let average = AudioManager.equivalentDecibelLevel(linearPowerSum: powerSum, sampleCount: 2)!

        #expect(abs(average - 67.4036) < 0.001)
    }

    @Test func equivalentDecibelLevelRejectsInvalidInputs() {
        #expect(AudioManager.linearPower(forDecibel: .nan) == nil)
        #expect(AudioManager.equivalentDecibelLevel(linearPowerSum: 0.0, sampleCount: 2) == nil)
        #expect(AudioManager.equivalentDecibelLevel(linearPowerSum: 1.0, sampleCount: 0) == nil)
    }

    @Test func fftAnalyzerReturnsZerosForShortInput() {
        let analyzer = FFTAnalyzer(fftSize: 8)
        let magnitudes = analyzer.analyze(samples: [0.1, 0.2])

        #expect(magnitudes == Array(repeating: 0.0, count: 4))
    }

    @Test func fftFrequencyBandsHandleEmptyAndZeroBandInputs() {
        let analyzer = FFTAnalyzer(fftSize: 8)

        #expect(analyzer.getFrequencyBands(magnitudes: [], bandCount: 4) == Array(repeating: 0.0, count: 4))
        #expect(analyzer.getFrequencyBands(magnitudes: [0.1, 0.2], bandCount: 0).isEmpty)
    }

    @Test func fftFrequencyBandsHandleSingleBandInput() {
        let analyzer = FFTAnalyzer(fftSize: 8)
        let bands = analyzer.getFrequencyBands(magnitudes: [0.1, 0.2, 0.3, 0.4], bandCount: 1)

        #expect(bands.count == 1)
        #expect(bands.allSatisfy { $0.isFinite })
    }

    @Test func fftAnalyzerSanitizesNonFiniteSamples() {
        let analyzer = FFTAnalyzer(fftSize: 8)
        let magnitudes = analyzer.analyze(samples: [.nan, .infinity, -.infinity, 0.1, -0.1, 0.2, -0.2, 0.0])

        #expect(magnitudes.count == 4)
        #expect(magnitudes.allSatisfy { $0.isFinite && (0.0...1.0).contains($0) })
    }

    @Test func fftFrequencyBandsClampNonFiniteMagnitudes() {
        let analyzer = FFTAnalyzer(fftSize: 8)
        let bands = analyzer.getFrequencyBands(
            magnitudes: [.nan, .infinity, -.infinity, 2.0, -1.0, 0.5],
            bandCount: 4
        )

        #expect(bands.count == 4)
        #expect(bands.allSatisfy { $0.isFinite && (0.0...1.0).contains($0) })
    }

    @Test func waveformCarouselSafeVisualizationIndexClampsOutOfRangeValues() {
        #expect(WaveformCarouselView.safeVisualizationIndex(3, count: 7) == 3)
        #expect(WaveformCarouselView.safeVisualizationIndex(-1, count: 7) == 0)
        #expect(WaveformCarouselView.safeVisualizationIndex(7, count: 7) == 0)
        #expect(WaveformCarouselView.safeVisualizationIndex(0, count: 0) == 0)
    }
}
