//
//  BasicOperations.swift
//  DZBLEManager_Example
//
//  Created by Demon on 10/16/25.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import Foundation
import DZBLEManager
import Combine

// 基础操作示例类
class BasicOperations {
    
     let manager = MultiDeviceBluetoothManager.shared
     var cancellables = Set<AnyCancellable>()
    
    // MARK: 3.1 扫描设备
    
    /// 开始扫描附近的蓝牙设备
    func startScanning() {
        manager.startScanning()
        print("🔍 开始扫描设备...")
        
        // 可选：10秒后自动停止扫描
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }
    
    /// 停止扫描
    func stopScanning() {
        manager.stopScanning()
        print("⏹️ 停止扫描")
    }
    
    // MARK: 3.2 连接设备
    
    /// 连接指定设备
    /// - Parameter device: 要连接的设备对象（从 deviceDiscovered 事件中获取）
    func connectDevice(_ device: BluetoothDevice) {

        device.$connectionState
               .receive(on: DispatchQueue.main)  // 1. 切换到主线程（重要！）
               .sink { [weak self] state in      // 2. 使用 weak self 避免循环引用
//                   self?.updateConnectionState(state)
               }
               .store(in: &cancellables)
        
        
        print("🔗 开始连接: \(device.name)")
        manager.connect(device: device)
        // 连接后会自动触发以下事件序列：
        // 1. connectionStateChanged(.connecting)
        // 2. deviceConnected
        // 3. connectionStateChanged(.connected)
        // 4. deviceReady
        // 5. connectionStateChanged(.ready)
    }
    
    /// 连接多个设备
    func connectMultipleDevices(_ devices: [BluetoothDevice]) {
        for device in devices {
            manager.connect(device: device)
            print("🔗 连接: \(device.name)")
        }
        
        // 所有设备并发连接，互不影响
    }
    
    // MARK: 3.3 断开设备
    
    /// 断开指定设备
    func disconnectDevice(_ device: BluetoothDevice) {
        print("🔌 断开: \(device.name)")
        manager.disconnect(device: device)
        
        // 会自动：
        // 1. 清理该设备的所有资源（指令队列、心跳、定时器）
        // 2. 触发 deviceDisconnected 事件
        // 3. 状态变为 .disconnected
    }
    
    /// 断开所有设备
    func disconnectAll() {
        print("🔌 断开所有设备")
        manager.disconnectAll()
    }
    
    // MARK: 3.4 查询状态
    
//    /// 获取所有已连接的设备
//    func getConnectedDevices() -> [BluetoothDevice] {
//        let devices = manager.connectedDevices
//        print("当前已连接 \(devices.count) 个设备")
//        
//        for device in devices {
//            print("  - \(device.name): \(device.connectionState.description)")
//        }
//        
//        return devices
//    }
//    
//    /// 检查设备是否可用
//    func checkDeviceReady(_ device: BluetoothDevice) -> Bool {
//        let isReady = device.connectionState == .ready
//        
//        if isReady {
//            print("✅ \(device.name) 可以使用")
//        } else {
//            print("❌ \(device.name) 不可用，当前状态: \(device.connectionState.description)")
//        }
//        
//        return isReady
//    }
}
