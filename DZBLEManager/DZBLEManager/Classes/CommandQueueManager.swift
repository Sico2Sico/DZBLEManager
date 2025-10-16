//
//  CommandQueueManager.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation
import CoreBluetooth
import Combine


class CommandQueueManager {
    private var commandQueue: [CommandTask] = []
    private var currentTask: CommandTask?
    private let lock = NSLock()
    
    func enqueue(command: DeviceCommand, completion: @escaping (CommandResult) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        commandQueue.append(CommandTask(command: command, completion: completion))
    }
    
    func dequeue() -> CommandTask? {
        lock.lock()
        defer { lock.unlock() }
        guard !commandQueue.isEmpty else { return nil }
        let task = commandQueue.removeFirst()
        currentTask = task
        return task
    }
    
    var isExecuting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentTask?.isExecuting ?? false
    }
    
    func completeCurrentTask() {
        lock.lock()
        defer { lock.unlock() }
        currentTask?.timer?.invalidate()
        currentTask = nil
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        commandQueue.removeAll()
        currentTask?.cancel()
        currentTask = nil
    }
}
