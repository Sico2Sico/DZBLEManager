//
//  DeviceConnectionState.swift
//  Pods
//
//  Created by Demon on 10/16/25.
//

// MARK: - 连接状态
public enum DeviceConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case ready
    case unstable
    case reconnecting
    
    var description: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .ready: return "就绪"
        case .unstable: return "不稳定"
        case .reconnecting: return "重连中"
        }
    }
}
