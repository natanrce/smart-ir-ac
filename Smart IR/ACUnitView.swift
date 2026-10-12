//
//  ACUnitView.swift
//  Smart IR
//

import SwiftUI

struct ACUnitView: View {
    let state: ACState
    let accent: Color

    var body: some View {
        VStack(spacing: 0) {
            unit
                .zIndex(1)
            AirflowView(isOn: state.power, intensity: intensity, color: accent)
                .frame(height: 56)
                .padding(.top, -4)
        }
        .frame(maxWidth: .infinity)
    }

    private var intensity: Double {
        if state.turbo { return 1 }
        switch state.fan {
        case .low: return 0.45
        case .mid: return 0.65
        case .high: return 0.9
        case .auto: return 0.7
        }
    }

    private var unit: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
            .frame(width: 220, height: 64)
            .overlay(alignment: .bottom) {
                VStack(spacing: 3) {
                    Capsule()
                        .fill(Color(white: 0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color(white: 0.7))
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 9)
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color(white: 0.75))
                    .frame(width: 4, height: 4)
                    .padding(.leading, 34)
                    .padding(.top, 18)
            }
            .overlay(alignment: .topTrailing) {
                LEDDisplay(value: state.temp)
                    .opacity(state.power ? 1 : 0)
                    .padding(.trailing, 32)
                    .padding(.top, 14)
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}

private struct AirflowView: View {
    let isOn: Bool
    let intensity: Double
    let color: Color

    private static let streaks: [(x: Double, speed: Double, phase: Double, length: Double)] = (0..<42).map { index in
        let seed = Double(index)
        return (
            x: (seed * 0.618).truncatingRemainder(dividingBy: 1),
            speed: 0.6 + (seed * 0.37).truncatingRemainder(dividingBy: 0.6),
            phase: (seed * 0.731).truncatingRemainder(dividingBy: 1),
            length: 0.18 + (seed * 0.29).truncatingRemainder(dividingBy: 0.22)
        )
    }

    var body: some View {
        TimelineView(.animation(paused: !isOn)) { timeline in
            Canvas { context, size in
                guard isOn else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                let top = size.width / 2
                for streak in Self.streaks {
                    let progress = (time * streak.speed * (0.5 + intensity) + streak.phase).truncatingRemainder(dividingBy: 1)
                    // Leaves the vent (~210 wide) and fans out as it falls
                    let startX = top + (streak.x - 0.5) * 180
                    let spread = (streak.x - 0.5) * 120 * intensity
                    let y0 = progress * size.height
                    let y1 = min(size.height, y0 + streak.length * size.height)
                    let x0 = startX + spread * progress
                    let x1 = startX + spread * (y1 / size.height)

                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: y0))
                    path.addLine(to: CGPoint(x: x1, y: y1))
                    let fade = (1 - progress) * intensity
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [color.opacity(0), color.opacity(0.6 * fade), color.opacity(0)]),
                            startPoint: CGPoint(x: x0, y: y0),
                            endPoint: CGPoint(x: x1, y: y1)
                        ),
                        lineWidth: 1.2
                    )
                }
            }
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
        .opacity(isOn ? 1 : 0)
    }
}

private struct LEDDisplay: View {
    let value: Int

    private static let color = Color(red: 1.0, green: 0.55, blue: 0.1)

    var body: some View {
        Text("\(value)")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Self.color)
            .shadow(color: Self.color.opacity(0.9), radius: 1.5)
            .shadow(color: Self.color.opacity(0.6), radius: 5)
    }
}
