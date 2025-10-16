import Foundation
import CoreBluetooth
import Combine

// MARK: - 设备类型
public enum DeviceType: String {
    case actionCamera = "运动相机"
    case smartBand = "手环"
    case smartWatch = "手表"
    case gimbal = "云台"
    case unknown = "未知设备"
    
    static func detect(from name: String) -> DeviceType {
        let lowercased = name.lowercased()
        if lowercased.contains("camera") || lowercased.contains("gopro") {
            return .actionCamera
        } else if lowercased.contains("band") {
            return .smartBand
        } else if lowercased.contains("watch") {
            return .smartWatch
        } else if lowercased.contains("gimbal") || lowercased.contains("osmo") {
            return .gimbal
        }
        return .unknown
    }
}
