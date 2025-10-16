//
//  HeartbeatManager.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation


struct HeartbeatCommand: DeviceCommand {
    let commandID: UInt8 = 0xFF
    let payload: Data
    let needsResponse: Bool = true
    let timeout: TimeInterval = 2.0
    let retryCount: Int = 1
    let isHeartbeat: Bool = true
    
    init(timestamp: Date) {
        var data = Data()
        let timeInterval = timestamp.timeIntervalSince1970
        withUnsafeBytes(of: timeInterval) { data.append(contentsOf: $0) }
        self.payload = data
    }
}



class HeartbeatManager {
    private var heartbeatTimer: Timer?
    private weak var device: BluetoothDevice?
    private var onHeartbeatFailed: (() -> Void)?
    private var sendHeartbeat: ((Date) -> Void)?
    
    init(device: BluetoothDevice) {
        self.device = device
    }
    
    func startHeartbeat(sendHeartbeat: @escaping (Date) -> Void, onFailed: @escaping () -> Void) {
        self.sendHeartbeat = sendHeartbeat
        self.onHeartbeatFailed = onFailed
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            sendHeartbeat(Date())
        }
    }
    
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
    }
    
    func onHeartbeatResponse(sendTime: Date) {
        let latency = Date().timeIntervalSince(sendTime) * 1000
        device?.connectionQuality.heartbeatLatency = latency
        device?.connectionQuality.missedHeartbeats = 0
    }
}


