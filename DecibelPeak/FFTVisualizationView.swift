//
//  FFTVisualizationView.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import SwiftUI

struct FFTSpectrumView: View {
    let frequencyBands: [Float]
    let barCount: Int = 64
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(0..<min(barCount, frequencyBands.count), id: \.self) { index in
                    let amplitude = frequencyBands[index]
                    let height = CGFloat(amplitude) * geometry.size.height * 0.8
                    let normalizedHeight = max(2, height)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorForFrequency(index, amplitude: amplitude),
                                    colorForFrequency(index, amplitude: amplitude).opacity(0.3)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: normalizedHeight)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(.easeInOut(duration: 0.08), value: height)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func colorForFrequency(_ index: Int, amplitude: Float) -> Color {
        let frequencyRatio = Float(index) / Float(barCount - 1)
        
        // Color based on frequency range (matching UI theme)
        switch frequencyRatio {
        case 0.0..<0.2:  // Low frequencies (bass) - Blue to Purple
            return Color.blue.opacity(Double(0.6 + amplitude * 0.4))
        case 0.2..<0.4:  // Low-mid frequencies - Purple to Green
            return Color.purple.opacity(Double(0.6 + amplitude * 0.4))
        case 0.4..<0.6:  // Mid frequencies - Green to Yellow
            return Color.green.opacity(Double(0.6 + amplitude * 0.4))
        case 0.6..<0.8:  // High-mid frequencies - Yellow to Orange
            return Color.yellow.opacity(Double(0.6 + amplitude * 0.4))
        default:         // High frequencies (treble) - Orange to Red
            return Color.red.opacity(Double(0.6 + amplitude * 0.4))
        }
    }
}

struct FFTCircularView: View {
    let frequencyBands: [Float]
    let lineWidth: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circles
                ForEach(1..<4) { ring in
                    Circle()
                        .stroke(
                            Color.white.opacity(0.05),
                            lineWidth: 0.5
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(ring) / 4,
                            height: geometry.size.height * CGFloat(ring) / 4
                        )
                }

                ForEach(0..<frequencyBands.count, id: \.self) { index in
                    let angle = (Double(index) / Double(frequencyBands.count)) * 360
                    let amplitude = CGFloat(frequencyBands[index])
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let barHeight = amplitude * radius * 0.7

                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    colorForFrequency(index, amplitude: Float(amplitude)),
                                    colorForFrequency(index, amplitude: Float(amplitude)).opacity(0.2)
                                ]),
                                center: .bottom,
                                startRadius: 0,
                                endRadius: barHeight
                            )
                        )
                        .frame(width: lineWidth, height: max(1, barHeight))
                        .offset(y: -radius * 0.6 - barHeight / 2)
                        .rotationEffect(.degrees(angle))
                        .animation(.easeInOut(duration: 0.1), value: barHeight)
                }

                // Center dot
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.2)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 4
                        )
                    )
                    .frame(width: 8, height: 8)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    private func colorForFrequency(_ index: Int, amplitude: Float) -> Color {
        let frequencyRatio = Float(index) / Float(frequencyBands.count - 1)
        
        switch frequencyRatio {
        case 0.0..<0.2:
            return Color.blue
        case 0.2..<0.4:
            return Color.purple
        case 0.4..<0.6:
            return Color.green
        case 0.6..<0.8:
            return Color.yellow
        default:
            return Color.red
        }
    }
}

struct FFTWaterfallView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawWaterfall(context: context, size: size)
            }
        }
    }

    private func drawWaterfall(context: GraphicsContext, size: CGSize) {
        let data = audioManager.waterfallData
        guard !data.isEmpty else { return }

        let cols = data[0].count

        // Use fixed row count for consistent layout - no more stretching!
        let isLandscape = size.width > size.height
        let maxDisplayRows = isLandscape ? 60 : 80 // Fixed maximum based on orientation

        let cellWidth = size.width / CGFloat(cols)
        let cellHeight = size.height / CGFloat(maxDisplayRows) // Always use max, never actual count

        for rowIndex in 0..<maxDisplayRows {
            guard rowIndex < data.count else { break }
            let rowData = data[rowIndex]
            let y = CGFloat(rowIndex) * cellHeight

            for (colIndex, amplitude) in rowData.enumerated() {
                let x = CGFloat(colIndex) * cellWidth
                let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)

                let color = colorForFrequency(colIndex, amplitude: amplitude, totalCols: cols)
                // Use very low opacity for empty rows, normal calculation for data rows
                let opacity = amplitude == 0.0 ? 0.02 : Double(min(1.0, max(0.1, amplitude * 1.2 + 0.1)))

                context.fill(
                    Path(rect),
                    with: .color(color.opacity(opacity))
                )
            }
        }
    }

    private func colorForFrequency(_ index: Int, amplitude: Float, totalCols: Int) -> Color {
        let frequencyRatio = Float(index) / Float(max(totalCols - 1, 1))
        let logAmplitude = log10(max(0.001, amplitude) + 0.001) + 3.0 // Normalize to 0-3 range
        let normalizedAmplitude = min(1.0, max(0.0, logAmplitude / 3.0))

        // Create a perceptually uniform color mapping across frequency spectrum
        let hue = Double(1.0 - frequencyRatio * 0.8) // Blue to red spectrum (240° to 0°)
        let saturation = 0.8 + Double(normalizedAmplitude) * 0.2 // 80-100% saturation
        let brightness = 0.3 + Double(normalizedAmplitude) * 0.7 // 30-100% brightness

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

struct DbCurveView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var currentGeometry: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid lines
                ForEach(stride(from: 20, through: 120, by: 20).map { $0 }, id: \.self) { dbLevel in
                    let yPosition = yPositionForDb(Double(dbLevel), in: geometry.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yPosition))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: yPosition))
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }

                // dB curve with gradient fill
                if audioManager.timestampedDbHistory.count > 1 {
                    Path { path in
                        let currentTime = CACurrentMediaTime()
                        let timeWindow: TimeInterval = 10.0 // seconds of data to show
                        let pixelsPerSecond = geometry.size.width / CGFloat(timeWindow)

                        // Collect visible data points first to determine proper fill area
                        let targetOffscreenTime: TimeInterval = 0.3 // 1.5 data intervals (0.2s each)
                        let startOffset = CGFloat(targetOffscreenTime) * pixelsPerSecond
                        var visiblePoints: [(x: CGFloat, y: CGFloat)] = []

                        for dataPoint in audioManager.timestampedDbHistory {
                            let dataAge = currentTime - dataPoint.timestamp
                            let x = geometry.size.width + startOffset - (CGFloat(dataAge) * pixelsPerSecond)
                            let y = yPositionForDb(dataPoint.value, in: geometry.size.height)

                            // Calculate appearance progress for smooth entry
                            let timeSinceAppearance = currentTime - dataPoint.appearanceTime
                            let appearanceProgress = min(1.0, max(0.0, timeSinceAppearance / 0.075))

                            // Only include points that have started appearing and are within extended bounds
                            if appearanceProgress > 0 && x >= -100.0 && x <= geometry.size.width + startOffset + 50.0 {
                                visiblePoints.append((x: x, y: y))
                            }
                        }

                        // Only draw gradient fill if we have visible data points
                        if !visiblePoints.isEmpty {
                            // Start from bottom of leftmost visible point instead of x=0
                            let leftmostX = visiblePoints.map { $0.x }.min() ?? 0
                            path.move(to: CGPoint(x: leftmostX, y: geometry.size.height))

                            // Draw curve through all visible points
                            for point in visiblePoints {
                                path.addLine(to: CGPoint(x: point.x, y: point.y))
                            }

                            // Close path for gradient fill - go to bottom right of rightmost point
                            let rightmostX = visiblePoints.map { $0.x }.max() ?? geometry.size.width
                            path.addLine(to: CGPoint(x: rightmostX, y: geometry.size.height))
                            path.closeSubpath()
                        }
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                colorForDb(audioManager.dbHistory.last ?? 50).opacity(0.6),
                                colorForDb(audioManager.dbHistory.last ?? 50).opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipped() // Clip to view bounds for smooth edge transitions

                    // Curve line
                    Path { path in
                        let currentTime = CACurrentMediaTime()
                        let timeWindow: TimeInterval = 10.0 // seconds of data to show
                        let pixelsPerSecond = geometry.size.width / CGFloat(timeWindow)

                        let targetOffscreenTime: TimeInterval = 0.3 // 1.5 data intervals (0.2s each)
                        let startOffset = CGFloat(targetOffscreenTime) * pixelsPerSecond
                        for (index, dataPoint) in audioManager.timestampedDbHistory.enumerated() {
                            let dataAge = currentTime - dataPoint.timestamp
                            let x = geometry.size.width + startOffset - (CGFloat(dataAge) * pixelsPerSecond)
                            let y = yPositionForDb(dataPoint.value, in: geometry.size.height)

                            // Calculate appearance progress for smooth entry
                            let timeSinceAppearance = currentTime - dataPoint.appearanceTime
                            let appearanceProgress = min(1.0, max(0.0, timeSinceAppearance / 0.075))

                            // Only draw points that have started appearing and are within extended bounds
                            if appearanceProgress > 0 && x >= -100.0 && x <= geometry.size.width + startOffset + 50.0 {
                                // Natural smooth entry - no additional sliding needed since data starts offscreen

                                if index == 0 || path.isEmpty {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }
                    .stroke(
                        colorForDb(audioManager.dbHistory.last ?? 50),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .clipped() // Clip to view bounds for smooth edge transitions
                }

                // dB level labels
                ForEach([30, 60, 90, 120], id: \.self) { dbLevel in
                    let yPosition = yPositionForDb(Double(dbLevel), in: geometry.size.height)
                    Text("\(dbLevel) dB")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .position(x: 30, y: yPosition - 8)
                }
            }
            .onAppear {
                // Initialize geometry
                currentGeometry = geometry.size
            }
        }
    }

    private func yPositionForDb(_ db: Double, in height: CGFloat) -> CGFloat {
        let minDb: Double = 20
        let maxDb: Double = 130
        let normalizedDb = (db - minDb) / (maxDb - minDb)
        let clampedNormalized = max(0.0, min(1.0, normalizedDb))
        return height * (1.0 - CGFloat(clampedNormalized))
    }

    private func colorForDb(_ db: Double) -> Color {
        switch db {
        case 0..<40:
            return .blue
        case 40..<60:
            return .green
        case 60..<80:
            return .yellow
        case 80..<100:
            return .orange
        default:
            return .red
        }
    }
}
