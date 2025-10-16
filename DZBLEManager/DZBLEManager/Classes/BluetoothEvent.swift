//
//  BluetoothEvent.swift
//  DZBLEManager
//
//  Created by Demon on 10/16/25.
//

import Foundation


// 蓝牙系统状态（区别于设备连接状态）
public enum BluetoothSystemState: Equatable {
    case unknown        // 未知状态
    case resetting      // 重置中
    case unsupported    // 设备不支持蓝牙
    case unauthorized   // 未授权
    case poweredOff     // 蓝牙已关闭
    case poweredOn      // 蓝牙已开启
    
    var description: String {
        switch self {
        case .unknown: return "未知"
        case .resetting: return "重置中"
        case .unsupported: return "不支持蓝牙"
        case .unauthorized: return "未授权"
        case .poweredOff: return "蓝牙已关闭"
        case .poweredOn: return "蓝牙已开启"
        }
    }
    
    var canScan: Bool {
        return self == .poweredOn
    }
    
    var isAvailable: Bool {
        return self == .poweredOn
    }
}



// MARK: - 蓝牙事件
/// 蓝牙设备相关的所有事件类型
/// 通过 Combine 的 Publisher 发布，支持多个模块同时订阅
public enum BluetoothEvent {
    
    // MARK: - 设备发现事件
    
    /// 发现新设备
    /// - Parameter device: 被发现的蓝牙设备对象
    ///
    /// **触发时机：**
    /// - 调用 `startScanning()` 后，每发现一个新设备触发一次
    /// - 即使同一设备，如果 RSSI 变化，也可能多次触发（取决于扫描配置）
    ///
    /// **使用场景：**
    /// - 更新设备列表 UI
    /// - 记录可用设备
    /// - 过滤特定类型的设备（如只显示运动相机）
    ///
    /// **注意事项：**
    /// - 设备此时处于 `.disconnected` 状态
    /// - 只包含基本信息（名称、RSSI、设备类型）
    /// - 服务和特征尚未发现
    ///
    /// **示例：**
    /// ```swift
    /// case .deviceDiscovered(let device):
    ///     print("发现设备: \(device.name), 信号: \(device.connectionQuality.rssi)dBm")
    ///     devicesListView.append(device)
    /// ```
    case deviceDiscovered(BluetoothDevice)
    
    // MARK: - 连接相关事件
    
    /// 设备物理连接成功
    /// - Parameter device: 已连接的设备对象
    ///
    /// **触发时机：**
    /// - 调用 `connect(device:)` 后，蓝牙物理层握手成功时触发
    /// - 通常在调用连接后 1-3 秒内触发
    ///
    /// **设备状态：**
    /// - 从 `.connecting` 变为 `.connected`
    /// - ⚠️ 注意：此时设备还**不能使用**，需要等待 `.deviceReady` 事件
    ///
    /// **使用场景：**
    /// - 显示"连接成功"提示
    /// - 开始显示"正在初始化..."状态
    /// - 记录连接时间戳
    ///
    /// **后续流程：**
    /// - 系统自动开始发现服务（discoverServices）
    /// - 发现特征（discoverCharacteristics）
    /// - 最终触发 `.deviceReady` 事件
    ///
    /// **示例：**
    /// ```swift
    /// case .deviceConnected(let device):
    ///     print("✅ 设备已连接: \(device.name)")
    ///     showMessage("\(device.name) 连接成功，正在初始化...")
    ///     // ❌ 此时不能发送指令！需要等待 deviceReady
    /// ```
    case deviceConnected(BluetoothDevice)
    
    /// 设备断开连接
    /// - Parameter device: 已断开的设备对象
    ///
    /// **触发时机：**
    /// - 主动调用 `disconnect(device:)` 时
    /// - 设备主动断开（关机、超出范围、电量耗尽等）
    /// - 蓝牙意外中断（信号干扰、系统错误等）
    ///
    /// **设备状态：**
    /// - 变为 `.disconnected`
    /// - 所有资源已清理（指令队列、心跳定时器、RSSI监控等）
    ///
    /// **使用场景：**
    /// - 更新 UI，显示断开状态
    /// - 清理与该设备相关的数据
    /// - 决定是否自动重连
    /// - 记录断开原因（可选）
    ///
    /// **注意事项：**
    /// - 设备对象仍然有效，可以再次连接
    /// - 已发送但未完成的指令会自动取消
    /// - 如需区分主动断开和异常断开，可通过状态历史判断
    ///
    /// **示例：**
    /// ```swift
    /// case .deviceDisconnected(let device):
    ///     print("🔌 设备已断开: \(device.name)")
    ///     removeFromConnectedList(device)
    ///
    ///     // 可选：自动重连
    ///     if shouldAutoReconnect {
    ///         DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    ///             manager.connect(device: device)
    ///         }
    ///     }
    /// ```
    case deviceDisconnected(BluetoothDevice)
    
    /// 设备就绪，可以使用
    /// - Parameter device: 已就绪的设备对象
    ///
    /// **触发时机：**
    /// - 服务（Services）和特征（Characteristics）全部发现完成
    /// - 写特征（Write Characteristic）已找到
    /// - 通知特征（Notify Characteristic）已找到并订阅
    /// - 通常在 `.deviceConnected` 事件后 0.5-2 秒触发
    ///
    /// **设备状态：**
    /// - 从 `.connected` 变为 `.ready`
    /// - ✅ 这是唯一可以发送指令的状态
    ///
    /// **自动启动的功能：**
    /// - 心跳包监控（每3秒一次）
    /// - RSSI 信号监控（每2秒一次）
    /// - 连接质量统计
    ///
    /// **使用场景：**
    /// - 启用所有控制按钮
    /// - 自动发送初始化配置指令
    /// - 开始数据采集或监控
    /// - 显示设备详细信息
    ///
    /// **示例：**
    /// ```swift
    /// case .deviceReady(let device):
    ///     print("🎉 设备已就绪: \(device.name)")
    ///     enableControlButtons(for: device)
    ///
    ///     // 自动发送配置指令
    ///     device.sendCommand(GetDeviceInfoCommand()) { result in
    ///         print("设备信息: \(result)")
    ///     }
    ///
    ///     // 或者获取电量
    ///     device.sendCommand(CameraCommand.getBatteryLevel.toCommand()) { result in
    ///         if case .success(let data) = result {
    ///             updateBatteryUI(data)
    ///         }
    ///     }
    /// ```
    case deviceReady(BluetoothDevice)
    
    // MARK: - 状态监控事件
    
    /// 连接状态变化
    /// - Parameters:
    ///   - device: 状态发生变化的设备
    ///   - state: 新的连接状态
    ///
    /// **触发时机：**
    /// - 每次设备状态改变时触发
    /// - 覆盖所有状态转换：disconnected ↔ connecting ↔ connected ↔ ready ↔ unstable ↔ reconnecting
    ///
    /// **可能的状态转换：**
    /// ```
    /// disconnected → connecting → connected → ready
    ///                                            ↓
    ///                                         unstable
    ///                                            ↓
    ///                                       reconnecting
    ///                                            ↓
    ///                                       disconnected
    /// ```
    ///
    /// **使用场景：**
    /// - 实时更新 UI 状态指示器
    /// - 记录状态变化日志
    /// - 触发状态相关的业务逻辑
    /// - 统计连接稳定性
    ///
    /// **注意事项：**
    /// - 此事件是状态变化的"统一入口"
    /// - 其他连接事件（deviceConnected、deviceReady等）也会同时触发此事件
    /// - 可以通过此事件实现状态机逻辑
    ///
    /// **示例：**
    /// ```swift
    /// case .connectionStateChanged(let device, let state):
    ///     print("[\(device.name)] 状态变更: \(state.description)")
    ///
    ///     updateStatusIndicator(device: device, state: state)
    ///
    ///     // 根据状态执行不同逻辑
    ///     switch state {
    ///     case .ready:
    ///         enableAllFeatures(for: device)
    ///     case .unstable:
    ///         showWarning("连接不稳定")
    ///     case .disconnected:
    ///         disableAllFeatures(for: device)
    ///     default:
    ///         break
    ///     }
    /// ```
    case connectionStateChanged(BluetoothDevice, DeviceConnectionState)
    
    /// 连接质量变化
    /// - Parameter device: 质量发生变化的设备
    ///
    /// **触发时机：**
    /// - RSSI（信号强度）更新时（每2秒）
    /// - 心跳延迟变化时（每次心跳响应）
    /// - 指令成功率变化时（每次指令完成）
    /// - 心跳丢失次数变化时
    ///
    /// **包含的质量指标：**
    /// ```swift
    /// device.connectionQuality.rssi                // 信号强度 (dBm)
    /// device.connectionQuality.heartbeatLatency    // 心跳延迟 (ms)
    /// device.connectionQuality.missedHeartbeats    // 丢失心跳数
    /// device.connectionQuality.successRate         // 指令成功率 (0.0-1.0)
    /// device.connectionQuality.isHealthy           // 连接是否健康
    /// device.connectionQuality.qualityLevel        // 质量等级字符串
    /// ```
    ///
    /// **使用场景：**
    /// - 实时更新信号强度显示
    /// - 显示延迟和成功率统计
    /// - 连接质量告警
    /// - 调整传输策略（如降低数据量）
    /// - 数据分析和优化
    ///
    /// **频率控制建议：**
    /// - 此事件触发频率较高（2秒一次）
    /// - 建议使用防抖（debounce）减少 UI 更新频率
    /// - 或者只在质量等级变化时更新 UI
    ///
    /// **示例：**
    /// ```swift
    /// case .connectionQualityChanged(let device):
    ///     let quality = device.connectionQuality
    ///
    ///     print("[\(device.name)] 质量更新:")
    ///     print("  - RSSI: \(quality.rssi)dBm")
    ///     print("  - 延迟: \(Int(quality.heartbeatLatency))ms")
    ///     print("  - 成功率: \(Int(quality.successRate * 100))%")
    ///     print("  - 等级: \(quality.qualityLevel)")
    ///
    ///     // 更新 UI
    ///     updateQualityIndicator(device)
    ///
    ///     // 质量告警
    ///     if !quality.isHealthy {
    ///         showWarning("[\(device.name)] 连接质量较差")
    ///     }
    ///
    ///     // 根据信号强度调整策略
    ///     if quality.rssi < -80 {
    ///         // 信号弱，降低数据传输频率
    ///         reduceDataRate(for: device)
    ///     }
    /// ```
    case connectionQualityChanged(BluetoothDevice)
    
    // MARK: - 心跳监控事件
    
    /// 心跳包响应成功
    /// - Parameter device: 心跳正常的设备
    ///
    /// **触发时机：**
    /// - 每次收到心跳包响应时（默认每3秒）
    /// - 在超时时间（5秒）内收到响应
    ///
    /// **作用：**
    /// - 确认设备仍然在线且响应正常
    /// - 计算通信延迟（RTT - Round Trip Time）
    /// - 重置丢失心跳计数器
    ///
    /// **关联数据更新：**
    /// ```swift
    /// device.connectionQuality.heartbeatLatency    // 更新延迟
    /// device.connectionQuality.missedHeartbeats    // 重置为 0
    /// device.connectionQuality.lastHeartbeatTime   // 更新时间戳
    /// ```
    ///
    /// **使用场景：**
    /// - 显示实时延迟
    /// - 连接健康度监控
    /// - 性能统计和分析
    /// - 恢复不稳定状态到就绪状态
    ///
    /// **频率说明：**
    /// - 默认每3秒触发一次
    /// - 频率可配置（推荐范围：2-10秒）
    /// - 低功耗设备建议 5-10 秒
    /// - 实时控制设备建议 2-3 秒
    ///
    /// **示例：**
    /// ```swift
    /// case .heartbeatSuccess(let device):
    ///     let latency = Int(device.connectionQuality.heartbeatLatency)
    ///     print("💚 [\(device.name)] 心跳正常，延迟: \(latency)ms")
    ///
    ///     // 更新延迟显示
    ///     updateLatencyLabel(device, latency: latency)
    ///
    ///     // 如果之前是不稳定状态，现在可以恢复
    ///     if device.connectionState == .unstable {
    ///         print("✅ 连接已恢复稳定")
    ///     }
    ///
    ///     // 延迟过高警告
    ///     if latency > 500 {
    ///         showWarning("[\(device.name)] 延迟较高: \(latency)ms")
    ///     }
    /// ```
    case heartbeatSuccess(BluetoothDevice)
    
    /// 心跳包响应失败
    /// - Parameter device: 心跳异常的设备
    ///
    /// **触发时机：**
    /// - 连续丢失心跳包达到阈值（默认3次）
    /// - 单次心跳超时时间为 5 秒
    /// - 总计约 15 秒无响应时触发
    ///
    /// **可能原因：**
    /// - 设备信号太弱（RSSI < -85dBm）
    /// - 设备忙碌，无法及时响应
    /// - 信号干扰或遮挡
    /// - 设备即将断开或已假死
    ///
    /// **自动处理：**
    /// - 设备状态自动变为 `.unstable`
    /// - 可能触发自动重连机制
    /// - 继续尝试发送心跳（不会立即断开）
    ///
    /// **使用场景：**
    /// - 显示连接异常警告
    /// - 记录异常日志
    /// - 通知用户检查设备
    /// - 触发备用方案（如切换到其他设备）
    /// - 暂停非关键操作
    ///
    /// **严重程度分级：**
    /// - 丢失 1-2 次：轻微异常，继续监控
    /// - 丢失 3 次：触发此事件，标记为不稳定
    /// - 丢失 5+ 次：考虑主动断开或强制重连
    ///
    /// **注意事项：**
    /// - 此事件不意味着立即断开
    /// - 设备可能自动恢复（触发 heartbeatSuccess）
    /// - 可以继续尝试发送指令，但成功率会降低
    ///
    /// **示例：**
    /// ```swift
    /// case .heartbeatFailed(let device):
    ///     let missedCount = device.connectionQuality.missedHeartbeats
    ///     print("💔 [\(device.name)] 心跳异常，已丢失: \(missedCount)次")
    ///
    ///     // 显示警告
    ///     showWarning("[\(device.name)] 连接不稳定，请检查设备")
    ///
    ///     // 根据丢失次数决定策略
    ///     if missedCount >= 5 {
    ///         // 严重异常，主动断开
    ///         print("⚠️ 心跳持续失败，断开连接")
    ///         manager.disconnect(device: device)
    ///     } else {
    ///         // 尝试重连
    ///         print("🔄 尝试重新连接")
    ///         manager.requestReconnect(device: device)
    ///     }
    ///
    ///     // 暂停非关键操作
    ///     pauseDataSync(for: device)
    /// ```
    case heartbeatFailed(BluetoothDevice)
    
    
    // ⭐️ 新增：系统状态事件
    case bluetoothSystemStateChanged(BluetoothSystemState)
    case bluetoothPoweredOff           // 蓝牙关闭（特殊事件）
    case bluetoothPoweredOn            // 蓝牙开启（特殊事件）
    case bluetoothUnauthorized         // 蓝牙未授权
    case allDevicesDisconnected        // 所有设备已断开
}
