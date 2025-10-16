//
//  BluetoothProtocolManager.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothProtocolManager {
    private let headerBytes: [UInt8] = [0xAA, 0x55]
    private let footerBytes: [UInt8] = [0x0D, 0x0A]
    
    func buildPacket(command: DeviceCommand) -> [Data] {
        var packet = Data()
        packet.append(contentsOf: headerBytes)
        packet.append(command.commandID)
        packet.append(contentsOf: footerBytes)
        return [packet]
    }
    
    func parseResponse(data: Data) -> (commandID: UInt8, payload: Data)? {
        guard data.count >= 4 else { return nil }
        return (data[2], Data())
    }
}
