//
//  MultiDeviceBluetoothManager.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - 管理器协议（解耦）
public protocol DeviceManagerProtocol: AnyObject {
    func notifyEvent(_ event: BluetoothEvent)
    func requestReconnect(device: BluetoothDevice)
}


// MARK: - 多设备管理器（简化版）
public class MultiDeviceBluetoothManager: NSObject, DeviceManagerProtocol {

    /// shared
    public static let shared = MultiDeviceBluetoothManager()
    
    /// (私有）= 发射器，只有管理器能发送事件
    private let eventSubject = PassthroughSubject<BluetoothEvent, Never>()
    
    /// (公开）= 接收器，所有模块都能订阅
    public var eventPublisher: AnyPublisher<BluetoothEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    private var centralManager: CBCentralManager!
    private let protocolManager = BluetoothProtocolManager()
    
    /// 蓝牙系统状态
    @Published public private(set) var bluetoothState: BluetoothSystemState = .unknown
    
    /// 发现的设备
    public var discoveredDevices: [UUID: BluetoothDevice] = [:]
    
    /// 链接的设备
    public var connectedDevices: [UUID: BluetoothDevice] = [:]
    
    private var shouldAutoReconnect: Bool = false
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("🔍 开始扫描设备...")
    }
    
    public func stopScanning() {
        centralManager.stopScan()
    }
    
    public func connect(device: BluetoothDevice) {
        device.updateConnectionState(.connecting)
        centralManager.connect(device.peripheral, options: nil)
    }
    
    public func disconnect(device: BluetoothDevice) {
        device.cleanup()
        connectedDevices.removeValue(forKey: device.id)
        centralManager.cancelPeripheralConnection(device.peripheral)
        device.updateConnectionState(.disconnected)
    }
    
    public func disconnectAll() {
        for device in connectedDevices.values {
            disconnect(device: device)
        }
    }
    
    // MARK: - DeviceManagerProtocol
    public func notifyEvent(_ event: BluetoothEvent) {
        eventSubject.send(event)
    }
    
    public func requestReconnect(device: BluetoothDevice) {
        device.updateConnectionState(.reconnecting)
        centralManager.cancelPeripheralConnection(device.peripheral)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.centralManager.connect(device.peripheral, options: nil)
        }
    }
}



// MARK: - CBCentralManagerDelegate
extension MultiDeviceBluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
       
        let newState: BluetoothSystemState
                
        switch central.state {
        case .unknown:
            newState = .unknown
            
        case .resetting:
            newState = .resetting
            
        case .unsupported:
            newState = .unsupported
            
        case .unauthorized:
            newState = .unauthorized
            
        case .poweredOff:
            newState = .poweredOff
            
        case .poweredOn:
            newState = .poweredOn
            
        @unknown default:
            newState = .unknown
        }
        
        // ⭐️ 处理状态变化
        handleBluetoothStateChange(newState)

    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        
        let deviceName = peripheral.name ?? "未知设备"
        let deviceType = DeviceType.detect(from: deviceName)
        
        // ⭐️ 创建设备时，设备自己管理 peripheral.delegate
        let device = BluetoothDevice(
            id: peripheral.identifier,
            name: deviceName,
            rssi: RSSI.intValue,
            peripheral: peripheral,
            deviceType: deviceType,
            manager: self,
            protocolManager: protocolManager
        )
        
        discoveredDevices[peripheral.identifier] = device
        eventSubject.send(.deviceDiscovered(device))
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = discoveredDevices[peripheral.identifier] else { return }
        
        // ⭐️ 注意：不需要设置 peripheral.delegate，因为设备创建时已经设置
        // peripheral.delegate = self  // ❌ 不需要！
        
        connectedDevices[device.id] = device
        device.updateConnectionState(.connected)
        eventSubject.send(.deviceConnected(device))
        
        print("✅ 设备已连接: \(device.name)")
        
        // 设备自己负责发现服务
        device.discoverServices()
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        
        guard let device = connectedDevices[peripheral.identifier] else { return }
        
        device.cleanup()
        connectedDevices.removeValue(forKey: device.id)
        device.updateConnectionState(.disconnected)
        eventSubject.send(.deviceDisconnected(device))
        
        print("🔌 设备已断开: \(device.name)")
    }
}


// MARK: - 系统蓝牙总开关关闭的情况 处理
extension MultiDeviceBluetoothManager  {
    
    /// 处理蓝牙状态变化
        private func handleBluetoothStateChange(_ newState: BluetoothSystemState) {
            let oldState = bluetoothState
            bluetoothState = newState
            
            print("📡 蓝牙状态变化: \(oldState.description) → \(newState.description)")
            
            // 发布系统状态变化事件
            eventSubject.send(.bluetoothSystemStateChanged(newState))
            
            switch newState {
            case .poweredOff:
                handleBluetoothPoweredOff()
                
            case .poweredOn:
                handleBluetoothPoweredOn(from: oldState)
                
            case .unauthorized:
                handleBluetoothUnauthorized()
                
            case .unsupported:
                handleBluetoothUnsupported()
                
            case .resetting:
                handleBluetoothResetting()
                
            case .unknown:
                break
            }
        }
        
        /// 蓝牙关闭处理 ⭐️ 关键
        private func handleBluetoothPoweredOff() {
            print("🔴 蓝牙已关闭，清理所有设备...")
            
            // 1. 停止扫描
            stopScanning()
            
            // 2. 保存当前已连接的设备（用于自动重连）
            if shouldAutoReconnect {
//                devicesBeforePowerOff = connectedDevices
//                print("💾 已保存 \(devicesBeforePowerOff.count) 个设备用于自动重连")
            }
            
            // 3. 更新所有已连接设备的状态为断开
            let devicesToDisconnect = Array(connectedDevices.values)
            for device in devicesToDisconnect {
                // 清理设备资源（心跳、定时器等）
                device.cleanup()
                
                // 更新设备状态
                device.updateConnectionState(.disconnected)
                
                // 发送断开事件
                eventSubject.send(.deviceDisconnected(device))
                
                print("🔌 [\(device.name)] 因蓝牙关闭而断开")
            }
            
            // 4. 清空设备集合
            connectedDevices.removeAll()
//            syncConnectedDevicesList()
            
            // 5. 清空已发现设备
            discoveredDevices.removeAll()
//            syncDiscoveredDevicesList()
            
            // 6. 发送特殊事件
            eventSubject.send(.bluetoothPoweredOff)
            eventSubject.send(.allDevicesDisconnected)
            
            print("✅ 所有设备已清理完成")
        }
        
        /// 蓝牙开启处理
        private func handleBluetoothPoweredOn(from oldState: BluetoothSystemState) {
            print("🟢 蓝牙已开启")
            
            eventSubject.send(.bluetoothPoweredOn)
//            
//            // 如果启用了自动重连，且之前有已连接的设备
//            if shouldAutoReconnect && !devicesBeforePowerOff.isEmpty {
//                print("🔄 检测到自动重连，准备重连 \(devicesBeforePowerOff.count) 个设备...")
//                
//                // 延迟1秒后开始重连
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
//                    self?.attemptAutoReconnect()
//                }
//            }
        }
        
        /// 自动重连
        private func attemptAutoReconnect() {
            print("🔄 开始自动重连...")
//            
//            let devicesToReconnect = Array(devicesBeforePowerOff.values)
//            
//            for device in devicesToReconnect {
//                print("🔄 重连: \(device.name)")
//                connect(device: device)
//                
//                // 间隔100ms，避免同时连接太多设备
//                Thread.sleep(forTimeInterval: 0.1)
//            }
//            
//            // 清空保存的设备
//            devicesBeforePowerOff.removeAll()
        }
        
        /// 蓝牙未授权处理
        private func handleBluetoothUnauthorized() {
            print("⚠️ 蓝牙未授权，请在设置中允许应用使用蓝牙")
            eventSubject.send(.bluetoothUnauthorized)
            
            // 清理所有设备
            handleBluetoothPoweredOff()
        }
        
        /// 设备不支持蓝牙
        private func handleBluetoothUnsupported() {
            print("❌ 设备不支持蓝牙")
            
            // 清理所有设备
            handleBluetoothPoweredOff()
        }
        
        /// 蓝牙重置中
        private func handleBluetoothResetting() {
            print("⚠️ 蓝牙正在重置...")
            
            // 清理所有设备
            handleBluetoothPoweredOff()
        }
        
}
