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

    @Test func waveformCarouselSafeVisualizationIndexClampsOutOfRangeValues() {
        #expect(WaveformCarouselView.safeVisualizationIndex(3, count: 7) == 3)
        #expect(WaveformCarouselView.safeVisualizationIndex(-1, count: 7) == 0)
        #expect(WaveformCarouselView.safeVisualizationIndex(7, count: 7) == 0)
        #expect(WaveformCarouselView.safeVisualizationIndex(0, count: 0) == 0)
    }
}
