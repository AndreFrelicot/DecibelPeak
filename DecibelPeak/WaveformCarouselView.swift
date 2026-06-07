    //
//  WaveformCarouselView.swift
//  DbMeter
//
//  Created by André Frélicot on 12/09/2025.
//

import SwiftUI

struct WaveformCarouselView: View {
    let samples: [Float]
    let frequencyBands: [Float]
    let isRecording: Bool
    @ObservedObject var audioManager: AudioManager
    @State private var autoScroll = true
    
    private static let visualizations = ["viz_wave", "viz_spectrum", "viz_fft_bars", "viz_fft_circle", "viz_waterfall", "viz_db_curve", "viz_db_peak"]

    private var selectedVisualizationIndex: Int {
        Self.safeVisualizationIndex(audioManager.selectedVisualization, count: Self.visualizations.count)
    }

    private var isDbPeakSelected: Bool {
        Self.visualizations[selectedVisualizationIndex] == "viz_db_peak"
    }

    private var selectedVisualizationBinding: Binding<Int> {
        Binding(
            get: { selectedVisualizationIndex },
            set: { audioManager.selectedVisualization = Self.safeVisualizationIndex($0, count: Self.visualizations.count) }
        )
    }

    static func safeVisualizationIndex(_ index: Int, count: Int) -> Int {
        guard count > 0, (0..<count).contains(index) else { return 0 }
        return index
    }

    private func sessionAverageText(_ value: Double) -> String {
        let format = String(localized: "session_average_db_format")
        return String.localizedStringWithFormat(format, Int64(value.rounded()))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey(Self.visualizations[selectedVisualizationIndex]))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if isDbPeakSelected, let sessionAverageDb = audioManager.sessionAverageDb {
                    Text(sessionAverageText(sessionAverageDb))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(4)
                }

                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<Self.visualizations.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedVisualizationIndex ? .white : .white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    audioManager.selectedVisualization = index
                                    autoScroll = false
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 8)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
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
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    TabView(selection: selectedVisualizationBinding) {
                        WaveformView(
                            samples: samples,
                            color: .white,
                            lineWidth: 2
                        )
                        .padding()
                        .tag(0)
                        
                        SpectrumView(samples: samples)
                            .padding()
                            .tag(1)
                        
                        FFTSpectrumView(frequencyBands: frequencyBands)
                            .padding()
                            .tag(2)
                        
                        FFTCircularView(frequencyBands: frequencyBands)
                            .padding()
                            .tag(3)
                        
                        FFTWaterfallView(audioManager: audioManager)
                            .padding()
                            .tag(4)

                        DbCurveView(audioManager: audioManager)
                            .padding()
                            .tag(5)

                        DbPeakView(audioManager: audioManager)
                            .padding()
                            .tag(6)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: audioManager.selectedVisualization)
                )
                .opacity(isRecording ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.5), value: isRecording)
        }
        .onReceive(Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()) { _ in
            if autoScroll && isRecording {
                withAnimation(.easeInOut(duration: 0.5)) {
                    audioManager.selectedVisualization = (selectedVisualizationIndex + 1) % Self.visualizations.count
                }
            }
        }
        .onTapGesture {
            autoScroll = false
            withAnimation(.easeInOut(duration: 0.3)) {
                audioManager.selectedVisualization = (selectedVisualizationIndex + 1) % Self.visualizations.count
            }
        }
    }
}
