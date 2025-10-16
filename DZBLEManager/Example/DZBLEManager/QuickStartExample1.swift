//
//  QuickStartExample1.swift
//  DZBLEManager_Example
//
//  Created by Demon on 10/16/25.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import Foundation
import DZBLEManager
import Combine


// 最简单的使用示例
class QuickStartExample {
    
    private let manager = MultiDeviceBluetoothManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    func quickStart() {
        // Step 1: 监听事件
        setupEventListener()
        
        // Step 2: 开始扫描
        manager.startScanning()
        
        // Step 3: 在事件中处理连接（见下方 setupEventListener）
    }
    
    private func setupEventListener() {
        manager.eventPublisher
            .sink { [weak self] event in
                switch event {
                case .deviceDiscovered(let device):
                    print("发现设备: \(device.name)")
                    // 自动连接第一个设备
                    self?.manager.connect(device: device)
                    
                case .deviceReady(let device):
                    print("设备就绪: \(device.name)")
                    // 发送指令
                    self?.sendTestCommand(to: device)
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func sendTestCommand(to device: BluetoothDevice) {
        // 示例：发送拍照指令
//        let command = CameraCommand.takePicture.toCommand()
//        
//        manager.sendCommand(command, to: device) { result in
//            switch result {
//            case .success:
//                print("指令成功")
//            case .failure(let error):
//                print("指令失败: \(error)")
//            case .timeout:
//                print("指令超时")
//            }
//        }
    }
}
