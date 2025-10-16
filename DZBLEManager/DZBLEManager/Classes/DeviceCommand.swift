//
//  DeviceCommand.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation


// MARK: - 指令协议
protocol DeviceCommand {
    var commandID: UInt8 { get }
    var payload: Data { get }
    var needsResponse: Bool { get }
    var timeout: TimeInterval { get }
    var retryCount: Int { get }
    var isHeartbeat: Bool { get }
}

extension DeviceCommand {
    var isHeartbeat: Bool { false }
}

// MARK: - 指令结果
enum CommandResult {
    case success(Data?)
    case failure(CommandError)
    case timeout
}

enum CommandError: Error {
    case deviceNotConnected
    case characteristicNotFound
    case sendFailed
    case timeout
}
