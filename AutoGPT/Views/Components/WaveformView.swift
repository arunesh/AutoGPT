//
//  WaveformView.swift
//  AutoGPT
//
//  Animated waveform visualization
//

import SwiftUI

struct WaveformView: View {
    let isActive: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 5)

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: isActive ? amplitudes[index] * 30 : 3)
                    .animation(.easeInOut(duration: 0.3), value: amplitudes[index])
            }
        }
        .frame(width: 30, height: 30)
        .onReceive(timer) { _ in
            if isActive {
                withAnimation {
                    amplitudes = (0..<5).map { _ in CGFloat.random(in: 0.3...1.0) }
                }
            } else {
                withAnimation {
                    amplitudes = Array(repeating: 0.3, count: 5)
                }
            }
        }
    }
}
