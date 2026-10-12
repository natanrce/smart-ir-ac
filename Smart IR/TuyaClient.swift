//
//  TuyaClient.swift
//  Smart IR
//
//  Local sending to Tuya protocol 3.3 devices (same framing as tinytuya):
//  55AA | seq | cmd | len | "3.3" + 12x00 + AES-ECB(json) | crc32 | AA55
//

import CommonCrypto
import Foundation
import Network

nonisolated struct TuyaDevice {
    var id: String
    var host: String
    var localKey: String
}

nonisolated enum TuyaError: LocalizedError {
    case connection(String)
    case timeout
    case encryption
    case device(UInt32)

    var errorDescription: String? {
        switch self {
        case .connection(let message): "Can't reach the hub: \(message)"
        case .timeout: "The hub didn't respond"
        case .encryption: "Invalid local key"
        case .device(let code): "The hub rejected the command (\(code))"
        }
    }
}

nonisolated struct TuyaClient {
    private static let port: NWEndpoint.Port = 6668
    private static let controlCommand: UInt32 = 7

    let device: TuyaDevice

    func setValue(dp: String, value: String) async throws {
        let json = #"{"devId":"\#(device.id)","uid":"\#(device.id)","t":"\#(Int(Date().timeIntervalSince1970))","dps":{"\#(dp)":\#(jsonString(value))}}"#
        try await send(frame(command: Self.controlCommand, json: json, sequence: 1))
    }

    func frame(command: UInt32, json: String, sequence: UInt32) throws -> Data {
        guard let encrypted = aesECB(Data(json.utf8), key: Data(device.localKey.utf8)) else {
            throw TuyaError.encryption
        }
        let payload = Data("3.3".utf8) + Data(count: 12) + encrypted
        var data = Data()
        data.appendBigEndian(0x0000_55AA)
        data.appendBigEndian(sequence)
        data.appendBigEndian(command)
        data.appendBigEndian(UInt32(payload.count + 8))
        data.append(payload)
        data.appendBigEndian(crc32(data))
        data.appendBigEndian(0x0000_AA55)
        return data
    }

    // The hub accepts only one local connection at a time, so we open and close per send
    private func send(_ data: Data) async throws {
        let connection = NWConnection(host: NWEndpoint.Host(device.host), port: Self.port, using: .tcp)
        defer { connection.cancel() }
        let queue = DispatchQueue(label: "smart-ir.tuya")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.resume()
                case .failed(let error), .waiting(let error): once.resume(throwing: TuyaError.connection(error.localizedDescription))
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 4) { once.resume(throwing: TuyaError.timeout) }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once(continuation)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    once.resume(throwing: TuyaError.connection(error.localizedDescription))
                } else {
                    once.resume()
                }
            })
        }

        // The response is optional (tinytuya uses nowait); it only detects rejection
        let response = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let once = Once(continuation)
            connection.receive(minimumIncompleteLength: 20, maximumLength: 1024) { content, _, _, _ in
                once.resume(returning: content)
            }
            queue.asyncAfter(deadline: .now() + 1.5) { once.resume(returning: nil) }
        }
        if let response, response.count >= 20, response.bigEndianUInt32(at: 0) == 0x0000_55AA {
            let code = response.bigEndianUInt32(at: 16)
            if code != 0 { throw TuyaError.device(code) }
        }
    }
}

private nonisolated final class Once<T, E: Error>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, E>?

    init(_ continuation: CheckedContinuation<T, E>) {
        self.continuation = continuation
    }

    private func take() -> CheckedContinuation<T, E>? {
        lock.lock()
        defer { lock.unlock() }
        let current = continuation
        continuation = nil
        return current
    }

    func resume(returning value: T) { take()?.resume(returning: value) }
    func resume(throwing error: E) { take()?.resume(throwing: error) }
}

private nonisolated extension Once where T == Void {
    func resume() { resume(returning: ()) }
}

private nonisolated func jsonString(_ value: String) -> String {
    var escaped = "\""
    for scalar in value.unicodeScalars {
        switch scalar {
        case "\"": escaped += "\\\""
        case "\\": escaped += "\\\\"
        default: escaped.unicodeScalars.append(scalar)
        }
    }
    return escaped + "\""
}

private nonisolated func aesECB(_ data: Data, key: Data) -> Data? {
    guard key.count == kCCKeySizeAES128 else { return nil }
    var output = Data(count: data.count + kCCBlockSizeAES128)
    var written = 0
    let outputCount = output.count
    let status = output.withUnsafeMutableBytes { out in
        data.withUnsafeBytes { input in
            key.withUnsafeBytes { keyBytes in
                CCCrypt(
                    CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, key.count, nil,
                    input.baseAddress, data.count,
                    out.baseAddress, outputCount, &written
                )
            }
        }
    }
    guard status == kCCSuccess else { return nil }
    return output.prefix(written)
}

private nonisolated let crcTable: [UInt32] = (0..<256).map { index in
    var crc = UInt32(index)
    for _ in 0..<8 {
        crc = crc & 1 == 1 ? 0xEDB8_8320 ^ (crc >> 1) : crc >> 1
    }
    return crc
}

private nonisolated func crc32(_ data: Data) -> UInt32 {
    ~data.reduce(~UInt32(0)) { crc, byte in
        crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
}

private nonisolated extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    func bigEndianUInt32(at offset: Int) -> UInt32 {
        let start = startIndex + offset
        return self[start..<start + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }
}
