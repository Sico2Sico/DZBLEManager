//
//  ConnectionQuality.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - 连接质量
struct ConnectionQuality {
    var rssi: Int
    var lastHeartbeatTime: Date
    var heartbeatLatency: TimeInterval
    var missedHeartbeats: Int
    var successRate: Double
    
    var isHealthy: Bool {
        rssi > -85 && missedHeartbeats < 3 && successRate > 0.8
    }
}
