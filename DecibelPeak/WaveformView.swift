//
//  WaveformView.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !samples.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let middle = height / 2
                let step = width / CGFloat(samples.count - 1)
                
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    // Use different scaling based on aspect ratio - vertical mode gets higher amplitude
                    let isVerticalMode = height > width
                    let amplitudeScale: CGFloat = isVerticalMode ? 2.5 : 1.2
                    let normalizedSample = CGFloat(sample) * middle * amplitudeScale
                    let y = middle - normalizedSample
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

struct SpectrumView: View {
    let samples: [Float]
    let barCount: Int = 40
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let sampleIndex = (index * samples.count) / barCount
                    let sample = sampleIndex < samples.count ? abs(samples[sampleIndex]) : 0
                    let height = min(CGFloat(sample) * geometry.size.height, geometry.size.height)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorForLevel(sample),
                                    colorForLevel(sample).opacity(0.6)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(4, height))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(.easeInOut(duration: 0.05), value: height)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    private func colorForLevel(_ level: Float) -> Color {
        switch level {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .yellow
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

struct CircularWaveformView: View {
    let samples: [Float]
    let lineWidth: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                
                ForEach(0..<samples.count, id: \.self) { index in
                    let angle = (Double(index) / Double(samples.count)) * 360 - 90
                    let sample = CGFloat(abs(samples[index]))
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let barHeight = sample * radius * 0.8
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorForLevel(Float(sample)),
                                    colorForLevel(Float(sample)).opacity(0.3)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: lineWidth, height: max(2, barHeight))
                        .offset(y: -radius / 2 - barHeight / 2)
                        .rotationEffect(.degrees(angle))
                        .animation(.easeInOut(duration: 0.1), value: barHeight)
                }
            }
        }
    }
    
    private func colorForLevel(_ level: Float) -> Color {
        switch level {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .yellow
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}