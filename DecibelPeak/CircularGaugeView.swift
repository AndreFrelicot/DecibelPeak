//
//  CircularGaugeView.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import SwiftUI

struct CircularGaugeView: View {
    let value: Double
    let isRecording: Bool
    let minValue: Double = 20
    let maxValue: Double = 130
    
    private var normalizedValue: Double {
        (value - minValue) / (maxValue - minValue)
    }
    
    private var rotation: Double {
        -135 + (normalizedValue * 270)
    }
    
    private var decibelColor: Color {
        switch value {
        case 0..<60:
            return .green
        case 60..<85:
            return .yellow
        case 85..<100:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let strokeWidth = size * 0.11 // ~30/280 of original
            let activeStrokeWidth = size * 0.125 // ~35/280 of original
            let tickOffset = size * 0.55 // ~155/280 of original
            let labelOffset = size * 0.66 // ~185/280 of original
            let centerTextWidth = size * 0.54 // ~150/280 of original
            let blurRadius = size * 0.07 // ~20/280 of original
            let glowRadius = size * 0.5 // ~140/280 of original

            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .green.opacity(0.3),
                                .yellow.opacity(0.3),
                                .orange.opacity(0.3),
                                .red.opacity(0.3)
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: isRecording ? normalizedValue * 0.75 : 0)
                    .stroke(
                        isRecording ? decibelColor.opacity(0.8) : Color.gray.opacity(0.1),
                        style: StrokeStyle(lineWidth: activeStrokeWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(135))
                    .shadow(color: isRecording ? decibelColor.opacity(0.5) : Color.clear, radius: size * 0.036)
                    .animation(.easeInOut(duration: 0.3), value: isRecording ? value : 0)

                ForEach(0..<12) { index in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(
                            width: index % 3 == 0 ? size * 0.011 : size * 0.0036,
                            height: index % 3 == 0 ? size * 0.054 : size * 0.036
                        )
                        .offset(y: -tickOffset)
                        .rotationEffect(.degrees(Double(index) * 22.5 - 135))
                }

                ForEach([20, 40, 60, 80, 100, 120], id: \.self) { db in
                    Text("\(db)")
                        .font(.system(size: size * 0.043, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .offset(y: -labelOffset)
                        .rotationEffect(.degrees(Double(db - 20) / 110 * 270 - 135))
                }

                VStack(spacing: size * 0.029) {
                    if isRecording && value > 0 {
                        Text(String(format: "%.0f", value))
                            .font(.system(size: size * 0.257, weight: .bold, design: .rounded))
                            .foregroundColor(decibelColor)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: value)
                    } else {
                        Text("–")
                            .font(.system(size: size * 0.257, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.5))
                            .animation(.easeInOut(duration: 0.3), value: isRecording)
                    }

                    Text(LocalizedStringKey("db_unit"))
                        .font(.system(size: size * 0.086, weight: .medium, design: .rounded))
                        .foregroundColor(isRecording ? .gray : .gray.opacity(0.5))
                        .animation(.easeInOut(duration: 0.3), value: isRecording)

                    Text(LocalizedStringKey(isRecording && value > 0 ? decibelDescription : "not_monitoring"))
                        .font(.system(size: size * 0.05, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(isRecording ? 1.0 : 0.6))
                        .multilineTextAlignment(.center)
                        .frame(width: centerTextWidth)
                        .animation(.easeInOut(duration: 0.3), value: isRecording)
                }

                if isRecording && value > 0 {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [decibelColor.opacity(0.3), Color.clear]),
                                center: .center,
                                startRadius: size * 0.018,
                                endRadius: glowRadius
                            )
                        )
                        .frame(width: size, height: size)
                        .blur(radius: blurRadius)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var decibelDescription: String {
        switch value {
        case 0..<30:
            return "level_very_quiet"
        case 30..<50:
            return "level_quiet"
        case 50..<60:
            return "level_moderate"
        case 60..<70:
            return "level_normal_conversation"
        case 70..<80:
            return "level_loud"
        case 80..<90:
            return "level_very_loud"
        case 90..<100:
            return "level_extremely_loud"
        case 100..<110:
            return "level_dangerous"
        case 110..<130:
            return "level_painful"
        default:
            return "level_threshold_of_pain"
        }
    }
}
