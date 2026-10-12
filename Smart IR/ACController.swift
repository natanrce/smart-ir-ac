//
//  ACController.swift
//  Smart IR
//
//  IR is one-way: each code carries the full state, so we keep the last state
//  sent and resend everything on every change (like elgin-smart/ac.py).
//

import Foundation
import Observation

struct HubConfig: Equatable {
    var roomName = "Bedroom"
    var deviceId = ""
    var host = ""
    var localKey = ""

    var device: TuyaDevice? {
        guard !deviceId.isEmpty, !host.isEmpty, localKey.utf8.count == 16 else { return nil }
        return TuyaDevice(id: deviceId, host: host, localKey: localKey)
    }

    // Production values come from Hub.json (kept out of git, holds the local key);
    // anything saved in the app's settings takes precedence.
    static func load(from defaults: UserDefaults = .standard) -> HubConfig {
        let bundled = Bundle.main.url(forResource: "Hub", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        func value(_ key: String) -> String? { defaults.string(forKey: key) ?? bundled[key] }

        var config = HubConfig()
        config.roomName = value("roomName") ?? config.roomName
        config.deviceId = value("deviceId") ?? ""
        config.host = value("host") ?? ""
        config.localKey = value("localKey") ?? ""
        return config
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(roomName, forKey: "roomName")
        defaults.set(deviceId, forKey: "deviceId")
        defaults.set(host, forKey: "host")
        defaults.set(localKey, forKey: "localKey")
    }
}

enum SyncStatus: Equatable {
    case unconfigured
    case idle
    case sending
    case synced
    case failed(String)
}

@Observable
final class ACController {
    private static let stateKey = "acState"

    private(set) var state: ACState
    private(set) var status: SyncStatus
    var config: HubConfig {
        didSet {
            config.save()
            status = config.device == nil ? .unconfigured : .idle
        }
    }

    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var queue: Task<Void, Never>?

    init() {
        let data = UserDefaults.standard.data(forKey: Self.stateKey) ?? Data()
        state = (try? JSONDecoder().decode(ACState.self, from: data)) ?? ACState()
        let config = HubConfig.load()
        self.config = config
        status = config.device == nil ? .unconfigured : .idle
    }

    func update(_ change: (inout ACState) -> Void) {
        var new = state
        change(&new)
        new.temp = min(max(new.temp, ACState.tempRange.lowerBound), ACState.tempRange.upperBound)
        guard new != state else { return }

        let powerChanged = new.power != state.power
        state = new
        if let data = try? JSONEncoder().encode(new) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
        // While off, changes are only stored for the next power on
        if new.power || powerChanged {
            scheduleStateSend(after: powerChanged ? .zero : .milliseconds(400))
        }
    }

    func toggleLight() {
        enqueue { ElectraCommand(state: $0, light: ElectraCommand.lightToggle) }
    }

    func clean() {
        enqueue { ElectraCommand(state: $0, clean: true) }
    }

    func resend() {
        scheduleStateSend(after: .zero)
    }

    private func scheduleStateSend(after delay: Duration) {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            enqueue { $0.power ? ElectraCommand(state: $0) : .powerOff }
        }
    }

    // Serialize sends: the hub accepts only one connection at a time
    private func enqueue(_ command: @escaping (ACState) -> ElectraCommand) {
        let previous = queue
        queue = Task {
            await previous?.value
            await transmit(command(state))
        }
    }

    private func transmit(_ command: ElectraCommand) async {
        guard let device = config.device else {
            status = .unconfigured
            return
        }
        status = .sending
        do {
            try await TuyaClient(device: device).setValue(dp: "201", value: command.irPayload)
            status = .synced
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
