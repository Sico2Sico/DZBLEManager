//
//  BluetoothDevice.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine


// MARK: - 蓝牙设备（自管理模式）⭐️
public class BluetoothDevice: NSObject, Identifiable, ObservableObject {
    public let id: UUID
    public let name: String
    public let peripheral: CBPeripheral
    public let deviceType: DeviceType
    
    @Published public var connectionState: DeviceConnectionState = .disconnected
    @Published public var connectionQuality: ConnectionQuality
    
    // 设备专属资源
    public var writeCharacteristic: CBCharacteristic?
    public var notifyCharacteristic: CBCharacteristic?
    public var responseBuffer = Data()
    
    // 依赖注入
    public weak var manager: DeviceManagerProtocol?
    private let protocolManager: BluetoothProtocolManager
    private let commandQueue: CommandQueueManager
    private var heartbeatManager: HeartbeatManager?
    private var rssiTimer: Timer?
    
    // 回调映射
    private var commandResponseMap: [UInt8: CommandTask] = [:]
    
    // 统计
    private var commandSuccessCount: Int = 0
    private var commandTotalCount: Int = 0
    
    init(id: UUID,
         name: String,
         rssi: Int,
         peripheral: CBPeripheral,
         deviceType: DeviceType,
         manager: DeviceManagerProtocol,
         protocolManager: BluetoothProtocolManager) {
        
        self.id = id
        self.name = name
        self.peripheral = peripheral
        self.deviceType = deviceType
        self.manager = manager
        self.protocolManager = protocolManager
        self.commandQueue = CommandQueueManager()
        self.connectionQuality = ConnectionQuality(
            rssi: rssi,
            lastHeartbeatTime: Date(),
            heartbeatLatency: 0,
            missedHeartbeats: 0,
            successRate: 1.0
        )
        
        super.init()
        
        // ⭐️ 关键：设备自己作为 delegate
        peripheral.delegate = self
        
        print("📱 [\(name)] 设备已创建，自管理模式")
    }
    
    // MARK: - 公共接口
    
    public func updateConnectionState(_ state: DeviceConnectionState) {
        connectionState = state
        manager?.notifyEvent(.connectionStateChanged(self, state))
    }
    
    func discoverServices() {
        peripheral.discoverServices(nil)
    }
    
    func sendCommand(_ command: DeviceCommand, completion: @escaping (CommandResult) -> Void) {
        guard connectionState == .ready else {
            completion(.failure(.deviceNotConnected))
            return
        }
        
        commandTotalCount += 1
        
        commandQueue.enqueue(command: command) { [weak self] result in
            if case .success = result {
                self?.commandSuccessCount += 1
            }
            self?.updateSuccessRate()
            completion(result)
        }
        
        processNextCommand()
    }
    
    func cleanup() {
        commandQueue.clear()
        heartbeatManager?.stopHeartbeat()
        heartbeatManager = nil
        rssiTimer?.invalidate()
        rssiTimer = nil
        responseBuffer.removeAll()
        commandResponseMap.removeAll()
        
        print("🧹 [\(name)] 资源已清理")
    }
    
    // MARK: - 内部处理
    
    private func processNextCommand() {
        guard !commandQueue.isExecuting else { return }
        guard let task = commandQueue.dequeue() else { return }
        executeCommand(task: task)
    }
    
    private func executeCommand(task: CommandTask) {
        guard let characteristic = writeCharacteristic else {
            task.completion(.failure(.characteristicNotFound))
            commandQueue.completeCurrentTask()
            processNextCommand()
            return
        }
        
        task.isExecuting = true
        task.attempts += 1
        
        print("⚡️ [\(name)] 执行指令: ID=\(task.command.commandID)")
        
        let packets = protocolManager.buildPacket(command: task.command)
        
        for packet in packets {
            peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        }
        
        if task.command.needsResponse {
            startTimeout(for: task)
            commandResponseMap[task.command.commandID] = task
        } else {
            task.completion(.success(nil))
            commandQueue.completeCurrentTask()
            processNextCommand()
        }
    }
    
    private func startTimeout(for task: CommandTask) {
        task.timer = Timer.scheduledTimer(withTimeInterval: task.command.timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout(task: task)
        }
    }
    
    private func handleTimeout(task: CommandTask) {
        commandResponseMap.removeValue(forKey: task.command.commandID)
        
        if task.attempts < task.command.retryCount {
            commandQueue.completeCurrentTask()
            commandQueue.enqueue(command: task.command, completion: task.completion)
            processNextCommand()
        } else {
            task.completion(.timeout)
            commandQueue.completeCurrentTask()
            processNextCommand()
        }
    }
    
    private func handleCommandResponse(commandID: UInt8, payload: Data) {
        // 心跳响应
        if commandID == 0xFF {
            if payload.count >= 8 {
                let timestamp = payload.withUnsafeBytes { $0.load(as: TimeInterval.self) }
                let date = Date(timeIntervalSince1970: timestamp)
                heartbeatManager?.onHeartbeatResponse(sendTime: date)
                manager?.notifyEvent(.heartbeatSuccess(self))
            }
            return
        }
        
        guard let task = commandResponseMap[commandID] else { return }
        
        task.timer?.invalidate()
        print("✅ [\(name)] 指令成功: ID=\(commandID)")
        
        task.completion(.success(payload))
        commandResponseMap.removeValue(forKey: commandID)
        commandQueue.completeCurrentTask()
        processNextCommand()
    }
    
    private func updateSuccessRate() {
        guard commandTotalCount > 0 else { return }
        let rate = Double(commandSuccessCount) / Double(commandTotalCount)
        connectionQuality.successRate = rate
    }
    
    func startHeartbeat() {
        heartbeatManager = HeartbeatManager(device: self)
        heartbeatManager?.startHeartbeat(
            sendHeartbeat: { [weak self] timestamp in
                self?.sendHeartbeatPacket(timestamp: timestamp)
            },
            onFailed: { [weak self] in
                self?.handleHeartbeatFailure()
            }
        )
    }
    
    private func sendHeartbeatPacket(timestamp: Date) {
        let heartbeat = HeartbeatCommand(timestamp: timestamp)
        guard let characteristic = writeCharacteristic else { return }
        
        let packets = protocolManager.buildPacket(command: heartbeat)
        for packet in packets {
            peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        }
    }
    
    private func handleHeartbeatFailure() {
        updateConnectionState(.unstable)
        manager?.notifyEvent(.heartbeatFailed(self))
        manager?.requestReconnect(device: self)
    }
    
    func startRSSIMonitoring() {
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.peripheral.readRSSI()
        }
    }
    
    deinit {
        cleanup()
        print("💀 [\(name)] 设备对象已释放")
    }
}



// MARK: - CBPeripheralDelegate（设备自己处理）⭐️
extension BluetoothDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        print("🔍 [\(name)] 发现 \(services.count) 个服务")
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) ||
               characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
                print("✍️ [\(name)] 找到写特征")
            }
            
            if characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("🔔 [\(name)] 订阅通知特征")
            }
        }
        
        // 检查是否就绪
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            updateConnectionState(.ready)
            manager?.notifyEvent(.deviceReady(self))
            
            // 启动心跳和RSSI监控
            startHeartbeat()
            startRSSIMonitoring()
            
            print("🎉 [\(name)] 设备已就绪")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        
        guard let data = characteristic.value else { return }
        
        responseBuffer.append(data)
        
        if let response = protocolManager.parseResponse(data: responseBuffer) {
            handleCommandResponse(commandID: response.commandID, payload: response.payload)
            responseBuffer.removeAll()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let rssiValue = RSSI.intValue
        connectionQuality.rssi = rssiValue
        
        manager?.notifyEvent(.connectionQualityChanged(self))
        
        // 根据RSSI调整状态
        if rssiValue < -85 && connectionState == .ready {
            updateConnectionState(.unstable)
        } else if rssiValue >= -70 && connectionState == .unstable {
            updateConnectionState(.ready)
        }
    }
}
