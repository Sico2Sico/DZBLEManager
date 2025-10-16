//
//  EventListeningExamples.swift
//  DZBLEManager_Example
//
//  Created by Demon on 10/16/25.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import Foundation
import DZBLEManager
import Combine



/// 事件监听示例
class EventListeningExamples {
    
    private let manager = MultiDeviceBluetoothManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: 4.1 监听所有事件
    
    func listenAllEvents() {
        manager.eventPublisher
            .receive(on: DispatchQueue.main)  // 切换到主线程（更新UI）
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleEvent(_ event: BluetoothEvent) {
        switch event {
        case .deviceDiscovered(let device):
            print("📱 发现设备: \(device.name)")
            
        case .deviceConnected(let device):
            print("✅ 连接成功: \(device.name)")
            
        case .deviceReady(let device):
            print("🎉 设备就绪: \(device.name)")
            
        case .deviceDisconnected(let device):
            print("🔌 设备断开: \(device.name)")
            
        case .connectionStateChanged(let device, let state): break
//            print("📡 [\(device.name)] 状态: \(state.description)")
            
        case .connectionQualityChanged(let device): break
//            let quality = device.connectionQuality
//            print("📊 [\(device.name)] RSSI: \(quality.rssi)dBm, 延迟: \(Int(quality.heartbeatLatency))ms")
            
        case .heartbeatSuccess(let device):
            print("💚 [\(device.name)] 心跳正常")
            
        case .heartbeatFailed(let device):
            print("💔 [\(device.name)] 心跳异常")
        }
    }
    
    // MARK: 4.2 只监听特定事件
    
    /// 只监听设备就绪事件
    func listenDeviceReady() {
        manager.eventPublisher
            .compactMap { event -> BluetoothDevice? in
                if case .deviceReady(let device) = event {
                    return device
                }
                return nil
            }
            .sink { device in
                print("🎉 设备就绪: \(device.name)")
                // 自动执行初始化操作
                self.initializeDevice(device)
            }
            .store(in: &cancellables)
    }
    
    /// 只监听特定设备的事件
    func listenSpecificDevice(_ targetDevice: BluetoothDevice) {
        manager.eventPublisher
            .sink { event in
                switch event {
                case .deviceReady(let device) where device.id == targetDevice.id:
                    print("目标设备就绪")
                    
                case .heartbeatFailed(let device) where device.id == targetDevice.id:
                    print("目标设备心跳异常")
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: 4.3 事件过滤和转换
    
    /// 监听连接质量变化并防抖
    func listenQualityWithDebounce() {
        manager.eventPublisher
            .filter { event in
                if case .connectionQualityChanged = event {
                    return true
                }
                return false
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)  // 1秒内只处理一次
            .sink { event in
                if case .connectionQualityChanged(let device) = event {
                    self.updateQualityUI(device)
                }
            }
            .store(in: &cancellables)
    }
    
    private func initializeDevice(_ device: BluetoothDevice) {
        // 初始化操作
    }
    
    private func updateQualityUI(_ device: BluetoothDevice) {
        // 更新UI
    }
}

// MARK: - 5️⃣ 发送指令详解

/// 指令发送示例
class CommandExamples {
    
    private let manager = MultiDeviceBluetoothManager.shared
    
    // MARK: 5.1 运动相机指令
    
    /// 拍照
    func takePicture(camera: BluetoothDevice) {
//        let command = CameraCommand.takePicture.toCommand()
//        
//        manager.sendCommand(command, to: camera) { result in
//            switch result {
//            case .success(let data):
//                print("✅ 拍照成功")
//                if let data = data {
//                    print("响应数据: \(data.hexString)")
//                }
//                
//            case .failure(let error):
//                print("❌ 拍照失败: \(error)")
//                
//            case .timeout:
//                print("⏰ 拍照超时")
//            }
//        }
    }
    
    /// 开始录制
    func startRecording(camera: BluetoothDevice) {
//        let command = CameraCommand.startRecording.toCommand()
//        
//        manager.sendCommand(command, to: camera) { result in
//            if case .success = result {
//                print("⏺ 开始录制")
//            }
//        }
    }
    
    /// 停止录制
    func stopRecording(camera: BluetoothDevice) {
//        let command = CameraCommand.stopRecording.toCommand()
//        
//        manager.sendCommand(command, to: camera) { result in
//            if case .success = result {
//                print("⏹ 停止录制")
//            }
//        }
    }
    
    /// 查询电量
    func getBatteryLevel(camera: BluetoothDevice) {
//        let command = CameraCommand.getBatteryLevel.toCommand()
//        
//        manager.sendCommand(command, to: camera) { result in
//            if case .success(let data) = result, let data = data {
//                let battery = data[0]  // 假设第一个字节是电量
//                print("🔋 电量: \(battery)%")
//            }
//        }
    }
    
    // MARK: 5.2 云台指令
    
    /// 云台左转
    func rotateLeft(gimbal: BluetoothDevice, speed: Int = 50) {
//        let command = GimbalCommand.rotateLeft(speed: speed).toCommand()
//        
//        manager.sendCommand(command, to: gimbal) { result in
//            if case .success = result {
//                print("⬅️ 云台左转，速度: \(speed)")
//            }
//        }
    }
    
    /// 云台归中（耗时操作）
    func centerPosition(gimbal: BluetoothDevice) {
//        let command = GimbalCommand.centerPosition.toCommand()
//        
//        print("🎯 云台归中中...")
//        
//        manager.sendCommand(command, to: gimbal) { result in
//            switch result {
//            case .success:
//                print("✅ 归中完成")
//                
//            case .timeout:
//                print("⏰ 归中超时（10秒）")
//                
//            default:
//                break
//            }
//        }
    }
    
    // MARK: 5.3 自定义指令
    
    /// 发送自定义指令
    func sendCustomCommand(to device: BluetoothDevice) {
//        // 创建自定义指令
//        let customCommand = GenericCommand(
//            commandID: 0x20,              // 自定义指令ID
//            payload: Data([0x01, 0x02]),  // 自定义数据
//            needsResponse: true,          // 需要响应
//            timeout: 3.0,                 // 3秒超时
//            retryCount: 2                 // 失败重试2次
//        )
//        
//        manager.sendCommand(customCommand, to: device) { result in
//            print("自定义指令结果: \(result)")
//        }
    }
    
    // MARK: 5.4 批量发送指令
    
    /// 顺序发送多个指令
    func sendMultipleCommands(to device: BluetoothDevice) {
//        // 指令会自动排队，按顺序执行
//        
//        // 指令1: 拍照
//        manager.sendCommand(CameraCommand.takePicture.toCommand(), to: device) { result in
//            print("1. 拍照: \(result)")
//        }
//        
//        // 指令2: 查询电量
//        manager.sendCommand(CameraCommand.getBatteryLevel.toCommand(), to: device) { result in
//            print("2. 电量: \(result)")
//        }
//        
//        // 指令3: 设置模式
//        manager.sendCommand(CameraCommand.setMode(2).toCommand(), to: device) { result in
//            print("3. 设置模式: \(result)")
//        }
//        
        // 这3个指令会按顺序执行，不会并发
    }
    
    // MARK: 5.5 异步等待方式（Swift 5.5+）
    
    /// 使用 async/await 发送指令
    func sendCommandAsync(to device: BluetoothDevice) async {
//        let command = CameraCommand.takePicture.toCommand()
//        
//        let result = await manager.sendCommand(command, to: device)
//        
//        switch result {
//        case .success:
//            print("✅ 拍照成功")
//        case .failure(let error):
//            print("❌ 失败: \(error)")
//        case .timeout:
//            print("⏰ 超时")
//        }
    }
    
    /// 顺序执行多个异步指令
    func sendMultipleCommandsAsync(to device: BluetoothDevice) async {
//        // 拍照
//        _ = await manager.sendCommand(CameraCommand.takePicture.toCommand(), to: device)
//        
//        // 延迟1秒
//        try? await Task.sleep(nanoseconds: 1_000_000_000)
//        
//        // 再次拍照
//        _ = await manager.sendCommand(CameraCommand.takePicture.toCommand(), to: device)
    }
}
