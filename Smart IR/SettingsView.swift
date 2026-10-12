//
//  SettingsView.swift
//  Smart IR
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @State var config: HubConfig
    let onClose: (HubConfig?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back", systemImage: "chevron.left") { onClose(nil) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                Text("IR Hub")
                    .font(.headline)
                Spacer()
            }
            .padding([.horizontal, .top], 16)

            Form {
                Section {
                    TextField("Room", text: $config.roomName, prompt: Text("Bedroom"))
                }
                Section {
                    TextField("Device ID", text: $config.deviceId, prompt: Text("IR 360 device id"))
                    TextField("IP", text: $config.host, prompt: Text("192.168.0.10"))
                    SecureField("Local key", text: $config.localKey, prompt: Text("16 characters"))
                } footer: {
                    Text("Get the id and local key with `python -m tinytuya wizard` (see elgin-smart/README.md). Protocol 3.3 only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Quit Smart IR") {
                    NSApplication.shared.terminate(nil)
                }
                Spacer()
                Button("Save") {
                    onClose(trimmed)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmed.device == nil)
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private var trimmed: HubConfig {
        var result = config
        result.roomName = result.roomName.trimmingCharacters(in: .whitespaces)
        result.deviceId = result.deviceId.trimmingCharacters(in: .whitespaces)
        result.host = result.host.trimmingCharacters(in: .whitespaces)
        if result.roomName.isEmpty { result.roomName = HubConfig().roomName }
        return result
    }
}
