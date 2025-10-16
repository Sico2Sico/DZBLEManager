//
//  MultiDeviceBluetoothManager.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine


// MARK: - 蓝牙事件
enum BluetoothEvent {
    case deviceDiscovered(BluetoothDevice)
    case deviceConnected(BluetoothDevice)
    case deviceDisconnected(BluetoothDevice)
    case deviceReady(BluetoothDevice)
    case connectionStateChanged(BluetoothDevice, DeviceConnectionState)
    case connectionQualityChanged(BluetoothDevice)
    case heartbeatSuccess(BluetoothDevice)
    case heartbeatFailed(BluetoothDevice)
}


// MARK: - 管理器协议（解耦）
protocol DeviceManagerProtocol: AnyObject {
    func notifyEvent(_ event: BluetoothEvent)
    func requestReconnect(device: BluetoothDevice)
}


// MARK: - 多设备管理器（简化版）
public class MultiDeviceBluetoothManager: NSObject, DeviceManagerProtocol {
    
    static let shared = MultiDeviceBluetoothManager()
    
    private let eventSubject = PassthroughSubject<BluetoothEvent, Never>()
    var eventPublisher: AnyPublisher<BluetoothEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    private var centralManager: CBCentralManager!
    private let protocolManager = BluetoothProtocolManager()
    
    private var discoveredDevices: [UUID: BluetoothDevice] = [:]
    private var connectedDevices: [UUID: BluetoothDevice] = [:]
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("🔍 开始扫描设备...")
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(device: BluetoothDevice) {
        device.updateConnectionState(.connecting)
        centralManager.connect(device.peripheral, options: nil)
    }
    
    func disconnect(device: BluetoothDevice) {
        device.cleanup()
        connectedDevices.removeValue(forKey: device.id)
        centralManager.cancelPeripheralConnection(device.peripheral)
        device.updateConnectionState(.disconnected)
    }
    
    func disconnectAll() {
        for device in connectedDevices.values {
            disconnect(device: device)
        }
    }
    
    // MARK: - DeviceManagerProtocol
    
    func notifyEvent(_ event: BluetoothEvent) {
        eventSubject.send(event)
    }
    
    func requestReconnect(device: BluetoothDevice) {
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
        if central.state == .poweredOn {
            print("✅ 蓝牙已开启")
        }
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
