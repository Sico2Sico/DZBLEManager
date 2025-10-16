//
//  CommandTask.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine

class CommandTask {
    let command: DeviceCommand
    let completion: (CommandResult) -> Void
    var attempts: Int = 0
    var timer: Timer?
    var isExecuting: Bool = false
    
    init(command: DeviceCommand, completion: @escaping (CommandResult) -> Void) {
        self.command = command
        self.completion = completion
    }
    
    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
