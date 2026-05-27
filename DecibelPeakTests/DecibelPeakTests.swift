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
}
