//
//  ContentView.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import SwiftUI
import UIKit

struct ResponsiveLayoutConfig {
    let visualizationSize: CGFloat
    let gaugeSizePercent: Double
    let spaceBetweenVisualizationAndCircularGauge: CGFloat
    let spaceBetweenCircularGaugeAndSpeakers: CGFloat
    let speakersScaling: Double
    let spaceBetweenSpeakersAndCaptureButton: CGFloat
}


struct ScreenSizeConfiguration {
    static func getLayoutConfig(for geometry: GeometryProxy) -> ResponsiveLayoutConfig {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let scale = UIScreen.main.scale

        let maxDimension = max(screenWidth, screenHeight)

        switch (maxDimension, scale) {
        case (667, 2.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 120,
                gaugeSizePercent: 0.60,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 0,
                speakersScaling: 0.8,
                spaceBetweenSpeakersAndCaptureButton: 0
            )
        case (728, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.70,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 0,
                speakersScaling: 0.8,
                spaceBetweenSpeakersAndCaptureButton: 0
            )
        case (814, 2.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 20
            )
        case (763, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.70,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 20
            )
        case (778, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 5,
                speakersScaling: 0.8,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        case (818, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 5,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 15
            )
        case (839, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        case (860, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        case (812, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.70,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 0,
                speakersScaling: 0.8,
                spaceBetweenSpeakersAndCaptureButton: 0
            )
        case (896, 2.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 20
            )
        case (844, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.70,
                spaceBetweenVisualizationAndCircularGauge: 40,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 20
            )
        case (852, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 5,
                speakersScaling: 0.8,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        case (896, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 5,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 15
            )
        case (932, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        case (956, 3.0):
            return ResponsiveLayoutConfig(
                visualizationSize: 160,
                gaugeSizePercent: 0.75,
                spaceBetweenVisualizationAndCircularGauge: 50,
                spaceBetweenCircularGaugeAndSpeakers: 20,
                speakersScaling: 1.0,
                spaceBetweenSpeakersAndCaptureButton: 10
            )
        default:
            if maxDimension <= 700 {
                return ResponsiveLayoutConfig(
                    visualizationSize: 120,
                    gaugeSizePercent: 0.60,
                    spaceBetweenVisualizationAndCircularGauge: 40,
                    spaceBetweenCircularGaugeAndSpeakers: 0,
                    speakersScaling: 0.8,
                    spaceBetweenSpeakersAndCaptureButton: 0
                )
            } else {
                return ResponsiveLayoutConfig(
                    visualizationSize: 160,
                    gaugeSizePercent: 0.75,
                    spaceBetweenVisualizationAndCircularGauge: 50,
                    spaceBetweenCircularGaugeAndSpeakers: 20,
                    speakersScaling: 1.0,
                    spaceBetweenSpeakersAndCaptureButton: 10
                )
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingPermissionAlert = false
    @State private var isLandscape = false

    private func decibelColor(for value: Double) -> Color {
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
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // Horizontal Layout
                    ZStack {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text(LocalizedStringKey("audio_analysis"))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(LocalizedStringKey("real_time_frequency_spectrum"))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 20)

                            WaveformCarouselView(
                                samples: audioManager.waveformSamples,
                                frequencyBands: audioManager.frequencyBands,
                                isRecording: audioManager.isRecording,
                                audioManager: audioManager
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 20)
                        }

                        // Floating elements
                        VStack {
                            Spacer()
                            HStack {
                                // dB value at bottom left
                                HStack(alignment: .bottom, spacing: 8) {
                                    if audioManager.isRecording && audioManager.decibelLevel > 0 {
                                        Text(String(format: "%.0f", audioManager.decibelLevel))
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(decibelColor(for: audioManager.decibelLevel))
                                            .contentTransition(.numericText())
                                            .animation(.easeInOut(duration: 0.2), value: audioManager.decibelLevel)
                                            .frame(width: 120, alignment: .trailing)
                                    } else {
                                        Text("–")
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(.gray.opacity(0.5))
                                            .animation(.easeInOut(duration: 0.3), value: audioManager.isRecording)
                                            .frame(width: 120, alignment: .trailing)
                                    }

                                    Text(LocalizedStringKey("db_unit"))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(audioManager.isRecording ? .gray : .gray.opacity(0.5))
                                        .animation(.easeInOut(duration: 0.3), value: audioManager.isRecording)
                                }
                                .padding(.leading, 5)

                                Spacer()

                                // Monitoring button at bottom right
                                Button(action: {
                                    if audioManager.isRecording {
                                        audioManager.stopMonitoring()
                                    } else {
                                        if audioManager.permissionGranted {
                                            audioManager.startMonitoring()
                                        } else {
                                            showingPermissionAlert = true
                                        }
                                    }
                                }) {
                                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            Circle().fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: audioManager.isRecording ? [.red, .orange] : [.green, .red]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        )
                                        .shadow(color: audioManager.isRecording ? .red.opacity(0.4) : .blue.opacity(0.4), radius: 10, y: 5)
                                }
                                .padding(.trailing, 30)
                            }
                            .padding(.bottom, 30)
                        }
                    }
                } else {

                    let config = ScreenSizeConfiguration.getLayoutConfig(for: geometry)
                    
                    // Vertical Layout (existing)
                    ScrollView {
                        VStack(spacing: 10) {
                            VStack(spacing: 8) {
                                Text(LocalizedStringKey("decibel_peak"))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(LocalizedStringKey("sound_level_monitor"))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 20)

                            WaveformCarouselView(
                                samples: audioManager.waveformSamples,
                                frequencyBands: audioManager.frequencyBands,
                                isRecording: audioManager.isRecording,
                                audioManager: audioManager
                            )
                            .frame(height: config.visualizationSize)
                            .padding(.horizontal, 20)

                            
                            let gaugeSize = (geometry.size.width - 40) * config.gaugeSizePercent
                            CircularGaugeView(value: audioManager.decibelLevel, isRecording: audioManager.isRecording)
                                .frame(width: gaugeSize, height: gaugeSize)
                                .padding(.vertical, config.spaceBetweenVisualizationAndCircularGauge)
                                //.border(Color.red)

                            VStack(spacing: config.spaceBetweenSpeakersAndCaptureButton) {
                                HStack(spacing: geometry.size.width < 375 ? 20 : 40) {
                                    SoundLevelIndicator(
                                        icon: "speaker.fill",
                                        label: String(localized: "level_quiet"),
                                        range: "20-60 dB",
                                        color: .green,
                                        isActive: audioManager.decibelLevel < 60
                                    )

                                    SoundLevelIndicator(
                                        icon: "speaker.wave.2.fill",
                                        label: String(localized: "level_moderate"),
                                        range: "60-85 dB",
                                        color: .yellow,
                                        isActive: audioManager.decibelLevel >= 60 && audioManager.decibelLevel < 85
                                    )

                                    SoundLevelIndicator(
                                        icon: "speaker.wave.3.fill",
                                        label: String(localized: "level_loud"),
                                        range: "85+ dB",
                                        color: .red,
                                        isActive: audioManager.decibelLevel >= 85
                                    )
                                }.scaleEffect(config.speakersScaling)
                                 .padding(config.spaceBetweenCircularGaugeAndSpeakers)
                                 //.border(Color.red)

                                Button(action: {
                                    if audioManager.isRecording {
                                        audioManager.stopMonitoring()
                                    } else {
                                        if audioManager.permissionGranted {
                                            audioManager.startMonitoring()
                                        } else {
                                            showingPermissionAlert = true
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 24))

                                        Text(LocalizedStringKey(audioManager.isRecording ? "stop_monitoring" : "start_monitoring"))
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: min(geometry.size.width - 40, 220), minHeight: 56)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: audioManager.isRecording ? [.red, .orange] : [.green, .red]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(28)
                                    .shadow(color: audioManager.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 10, y: 5)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                    }
                    .scrollDisabled(true)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(LocalizedStringKey("microphone_permission_message"))
        }
        .onAppear {
            if audioManager.permissionGranted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioManager.startMonitoring()
                }
            }
        }
    }
}

struct SoundLevelIndicator: View {
    let icon: String
    let label: String
    let range: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(isActive ? color : .gray.opacity(0.3))
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isActive)
            
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? .white : .gray.opacity(0.5))
            
            Text(range)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(isActive ? .gray : .gray.opacity(0.3))
        }
    }
}

#Preview {
    ContentView()
}
