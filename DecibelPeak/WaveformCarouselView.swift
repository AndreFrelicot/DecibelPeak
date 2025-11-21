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
    
    private let visualizations = ["viz_wave", "viz_spectrum", "viz_fft_bars", "viz_fft_circle", "viz_waterfall", "viz_db_curve"]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey(visualizations[audioManager.selectedVisualization]))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<visualizations.count, id: \.self) { index in
                        Circle()
                            .fill(index == audioManager.selectedVisualization ? .white : .white.opacity(0.3))
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
                    TabView(selection: $audioManager.selectedVisualization) {
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
                    audioManager.selectedVisualization = (audioManager.selectedVisualization + 1) % visualizations.count
                }
            }
        }
        .onTapGesture {
            autoScroll = false
            withAnimation(.easeInOut(duration: 0.3)) {
                audioManager.selectedVisualization = (audioManager.selectedVisualization + 1) % visualizations.count
            }
        }
    }
}