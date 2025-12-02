//
//  CalibrationOverlayView.swift
//  DecibelPeak
//
//  Calibration overlay that displays on top of the visualization zone.
//  Shows a slider for adjusting the calibration offset with cancel/validate buttons.
//

import SwiftUI

struct CalibrationOverlayView: View {
    @ObservedObject var audioManager: AudioManager

    // Gauge colors (matching CircularGaugeView)
    private let decibelBlue = Color(red: 0, green: 0.478, blue: 1) // iOS system blue
    private let decibelGreen = Color.green
    private let decibelYellow = Color.yellow
    private let decibelOrange = Color.orange
    private let decibelRed = Color.red

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95),
                            Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.95)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(spacing: 12) {
                // Top row: Cancel button, Title, Validate button
                HStack {
                    // Cancel button - top left
                    Button(action: {
                        audioManager.cancelCalibration()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }

                    Spacer()

                    // Title
                    Text("Calibration")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    // Validate button - top right
                    Button(action: {
                        audioManager.saveCalibration()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                }

                // Current value display
                Text(formatOffset(audioManager.tempCalibrationOffset))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(calibrationColor(for: audioManager.tempCalibrationOffset))

                // Range labels and slider
                VStack(spacing: 2) {
                    HStack {
                        Text("\(Int(AudioManager.minCalibrationOffset)) dB")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(decibelBlue)

                        Spacer()

                        Text("+\(Int(AudioManager.maxCalibrationOffset)) dB")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(decibelRed)
                    }

                    // Gradient slider
                    ZStack {
                        // Gradient track background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        decibelBlue,
                                        decibelGreen,
                                        decibelYellow,
                                        decibelOrange,
                                        decibelRed
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 4)

                        // Slider
                        Slider(
                            value: Binding(
                                get: { audioManager.tempCalibrationOffset },
                                set: { audioManager.setTempCalibrationOffset($0) }
                            ),
                            in: AudioManager.minCalibrationOffset...AudioManager.maxCalibrationOffset,
                            step: AudioManager.calibrationStep
                        )
                        .accentColor(.clear) // Hide default track
                        .tint(.clear)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// Format the offset value for display.
    /// Shows + sign for positive values, no sign for zero.
    private func formatOffset(_ offset: Double) -> String {
        let sign = offset > 0 ? "+" : ""
        return String(format: "%@%.1f dB", sign, offset)
    }

    /// Get color based on offset value using the gauge gradient.
    /// Maps -20 to +20 range to Blue → Green → Yellow → Orange → Red
    private func calibrationColor(for offset: Double) -> Color {
        // Normalize offset from [-20, +20] to [0, 1]
        let normalized = (offset - AudioManager.minCalibrationOffset) /
            (AudioManager.maxCalibrationOffset - AudioManager.minCalibrationOffset)
        let clamped = max(0, min(1, normalized))

        // Map to colors: Blue(0) → Green(0.25) → Yellow(0.5) → Orange(0.75) → Red(1.0)
        switch clamped {
        case 0..<0.25:
            let t = clamped / 0.25
            return lerpColor(from: decibelBlue, to: decibelGreen, t: t)
        case 0.25..<0.5:
            let t = (clamped - 0.25) / 0.25
            return lerpColor(from: decibelGreen, to: decibelYellow, t: t)
        case 0.5..<0.75:
            let t = (clamped - 0.5) / 0.25
            return lerpColor(from: decibelYellow, to: decibelOrange, t: t)
        default:
            let t = (clamped - 0.75) / 0.25
            return lerpColor(from: decibelOrange, to: decibelRed, t: t)
        }
    }

    /// Linear interpolation between two colors.
    private func lerpColor(from start: Color, to end: Color, t: Double) -> Color {
        let fraction = max(0, min(1, t))

        // Convert to UIColor to access RGB components
        let startUI = UIColor(start)
        let endUI = UIColor(end)

        var startR: CGFloat = 0, startG: CGFloat = 0, startB: CGFloat = 0, startA: CGFloat = 0
        var endR: CGFloat = 0, endG: CGFloat = 0, endB: CGFloat = 0, endA: CGFloat = 0

        startUI.getRed(&startR, green: &startG, blue: &startB, alpha: &startA)
        endUI.getRed(&endR, green: &endG, blue: &endB, alpha: &endA)

        return Color(
            red: startR + (endR - startR) * fraction,
            green: startG + (endG - startG) * fraction,
            blue: startB + (endB - startB) * fraction
        )
    }
}

#Preview {
    CalibrationOverlayView(audioManager: AudioManager())
        .frame(height: 200)
        .padding()
        .background(Color.black)
}
