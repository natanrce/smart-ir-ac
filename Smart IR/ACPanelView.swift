//
//  ACPanelView.swift
//  Smart IR
//

import SwiftUI

struct ACPanelView: View {
    @Bindable var controller: ACController
    @State private var showingSettings = false

    private var state: ACState { controller.state }

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(config: controller.config) { config in
                    if let config { controller.config = config }
                    showingSettings = false
                }
            } else {
                panel
            }
        }
        .frame(width: 320)
        .tint(state.mode.color)
        .animation(.snappy, value: state.power)
        .animation(.snappy, value: state.mode)
    }

    private var panel: some View {
        VStack(spacing: 14) {
            header
            ACUnitView(state: state, accent: state.mode.color)
            temperatureControl
            HStack(spacing: 8) {
                modeMenu
                fanMenu
            }
            HStack(spacing: 0) {
                CircleToggle(title: "Swing", symbol: "arrow.up.and.down", isOn: state.swingV, isEnabled: state.power) {
                    controller.update { $0.swingV.toggle() }
                }
                CircleToggle(title: "Turbo", symbol: "wind", isOn: state.turbo, isEnabled: state.power) {
                    controller.update { $0.turbo.toggle() }
                }
                CircleToggle(title: "Quiet", symbol: "moon.zzz", isOn: state.quiet, isEnabled: state.power) {
                    controller.update { $0.quiet.toggle() }
                }
            }
            Divider()
            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.config.roomName)
                    .font(.headline)
                Text(state.power ? "On · \(state.mode.label)" : "Off")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Power", isOn: Binding(get: { state.power }, set: { isOn in controller.update { $0.power = isOn } }))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(state.power ? "Turn Off" : "Turn On")
        }
    }

    private var temperatureControl: some View {
        HStack {
            StepButton(symbol: "minus") { controller.update { $0.temp -= 1 } }
                .disabled(state.temp <= ACState.tempRange.lowerBound)
                .help("Decrease temperature")
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(state.temp)")
                    .font(.system(size: 48, weight: .medium))
                    .contentTransition(.numericText(value: Double(state.temp)))
                Text("°C")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .foregroundStyle(state.power ? .primary : .secondary)
            .animation(.snappy, value: state.temp)
            Spacer()
            StepButton(symbol: "plus") { controller.update { $0.temp += 1 } }
                .disabled(state.temp >= ACState.tempRange.upperBound)
                .help("Increase temperature")
        }
    }

    private var modeMenu: some View {
        Menu {
            Picker("Mode", selection: Binding(get: { state.mode }, set: { mode in controller.update { $0.mode = mode } })) {
                ForEach(ACMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            MenuModule(title: "Mode", value: state.mode.label, symbol: state.mode.symbol, isOn: state.power)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var fanMenu: some View {
        Menu {
            Picker("Fan Speed", selection: Binding(get: { state.fan }, set: { fan in controller.update { $0.fan = fan } })) {
                ForEach(FanSpeed.allCases) { fan in
                    Text(fan.label).tag(fan)
                }
            }
            .pickerStyle(.inline)
        } label: {
            MenuModule(title: "Fan Speed", value: state.fan.label, symbol: "fan", isOn: state.power)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            SyncStatusView(status: controller.status)
            Spacer()
            Group {
                Button("Display Light", systemImage: "lightbulb", action: controller.toggleLight)
                Button("Self-Clean", systemImage: "sparkles", action: controller.clean)
            }
            .disabled(!state.power)
            Button("Resend State", systemImage: "arrow.clockwise", action: controller.resend)
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}

private struct CircleSymbol: View {
    let symbol: String
    let isOn: Bool
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(Circle().fill(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary)))
            .contentShape(Circle())
    }
}

private struct StepButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleSymbol(symbol: symbol, isOn: false, size: 36)
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

private struct MenuModule: View {
    let title: String
    let value: String
    let symbol: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            CircleSymbol(symbol: symbol, isOn: isOn, size: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
    }
}

private struct CircleToggle: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                CircleSymbol(symbol: symbol, isOn: isOn && isEnabled, size: 36)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct SyncStatusView: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 5) {
            switch status {
            case .sending:
                ProgressView()
                    .controlSize(.mini)
                Text("Sending…")
            case .synced:
                Image(systemName: "checkmark.circle")
                Text("Sent")
            case .idle:
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("Ready")
            case .unconfigured:
                Image(systemName: "exclamationmark.triangle")
                Text("Set up the IR hub")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .lineLimit(1)
                    .help(message)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension ACMode {
    var label: String {
        switch self {
        case .cool: "Cool"
        case .heat: "Heat"
        case .dry: "Dry"
        case .fan: "Fan"
        case .auto: "Auto"
        }
    }

    var symbol: String {
        switch self {
        case .cool: "snowflake"
        case .heat: "sun.max"
        case .dry: "drop"
        case .fan: "fan"
        case .auto: "thermometer.variable"
        }
    }

    var color: Color {
        switch self {
        case .cool: .blue
        case .heat: .orange
        case .dry: .teal
        case .fan: .mint
        case .auto: .indigo
        }
    }
}

extension FanSpeed {
    var label: String {
        switch self {
        case .auto: "Auto"
        case .low: "Low"
        case .mid: "Medium"
        case .high: "High"
        }
    }
}

#Preview {
    ACPanelView(controller: ACController())
}
