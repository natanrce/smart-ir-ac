//
//  Electra.swift
//  Smart IR
//
//  Port of elgin-smart/electra.py: Electra protocol IR codes
//  (IRremoteESP8266 ir_Electra.h) in Tuya's compressed format.
//

import Foundation

nonisolated enum ACMode: String, Codable, CaseIterable, Identifiable {
    case cool, heat, dry, fan, auto

    var id: Self { self }

    var bits: UInt8 {
        switch self {
        case .auto: 0b000
        case .cool: 0b001
        case .dry: 0b010
        case .heat: 0b100
        case .fan: 0b110
        }
    }
}

nonisolated enum FanSpeed: String, Codable, CaseIterable, Identifiable {
    case auto, low, mid, high

    var id: Self { self }

    var bits: UInt8 {
        switch self {
        case .auto: 0b101
        case .low: 0b011
        case .mid: 0b010
        case .high: 0b001
        }
    }
}

nonisolated struct ACState: Codable, Equatable {
    static let tempRange = 16...32

    var power = false
    var mode = ACMode.cool
    var temp = 23
    var fan = FanSpeed.auto
    var swingV = false
    var swingH = false
    var turbo = false
    var quiet = false
}

nonisolated struct ElectraCommand {
    static let head = "010ed800000000000500150041002600ae0159"
    static let lightToggle: UInt8 = 0x15
    // Power off identical to the Tuya library's 'power_off' (what the app sends)
    static let powerOff = ElectraCommand(
        state: ACState(power: false, mode: .cool, temp: 16, fan: .auto, swingV: true),
        light: 0x05
    )

    var state: ACState
    var clean = false
    var light: UInt8 = 0x00

    var bytes: [UInt8] {
        let swingOff: UInt8 = 0b111
        var b = [UInt8](repeating: 0, count: 13)
        b[0] = 0xC3
        b[1] = (state.swingV ? 0 : swingOff) | UInt8(state.temp - 8) << 3
        b[2] = (state.swingH ? 0 : swingOff) << 5
        b[4] = state.fan.bits << 5
        b[5] = (state.turbo ? 1 << 6 : 0) | (state.quiet ? 1 << 7 : 0)
        b[6] = state.mode.bits << 5
        b[9] = (clean ? 1 << 2 : 0) | (state.power ? 1 << 5 : 0)
        b[11] = light
        b[12] = UInt8(truncatingIfNeeded: b[..<12].reduce(0) { $0 + Int($1) })
        return b
    }

    // Tuya stores each byte with its bits reversed
    var tuyaKey: String {
        "01^%0068" + bytes.map { String(format: "%02X", reverseBits($0)) }.joined() + "@$"
    }

    // Same payload the app panel sends on DP 201: the hub decompresses
    // head+key1 itself; key1 is prefixed with '0'.
    var irPayload: String {
        #"{"control":"send_ir","head":"\#(Self.head)","key1":"0\#(tuyaKey)","type":0,"delay":300}"#
    }

    init(state: ACState, clean: Bool = false, light: UInt8 = 0x00) {
        self.state = state
        self.clean = clean
        self.light = light
    }
}

private nonisolated func reverseBits(_ byte: UInt8) -> UInt8 {
    var value = byte
    var result: UInt8 = 0
    for _ in 0..<8 {
        result = result << 1 | value & 1
        value >>= 1
    }
    return result
}
