//
//  PodBackupInfo.swift
//  OmniBLE
//
//  Created for FreeAPS X on 2025-11-29.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation

/// Информация о состоянии пода для отображения в UI
public struct PodBackupInfo {
    /// Pod Address (в hex формате)
    public let address: String
    
    /// Bluetooth UUID
    public let bleIdentifier: String
    
    /// LTK в hex формате
    public let ltkHex: String
    
    /// Firmware версия
    public let firmwareVersion: String
    
    /// Дата активации
    public let activatedAt: Date?
    
    /// Дата истечения срока
    public let expiresAt: Date?
    
    /// Статус установки
    public let setupProgress: SetupProgress
    
    /// Краткое описание для UI
    public var shortDescription: String {
        var parts: [String] = []
        parts.append("Pod ID: \(address)")
        parts.append("FW: \(firmwareVersion)")
        if let activatedAt = activatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            parts.append("Активирован: \(formatter.string(from: activatedAt))")
        }
        return parts.joined(separator: "\n")
    }
    
    /// Полное описание для копирования
    public var fullDescription: String {
        var parts: [String] = []
        parts.append("=== Omnipod DASH Backup Info ===")
        parts.append("")
        parts.append("Pod Address: \(address)")
        parts.append("Bluetooth UUID: \(bleIdentifier)")
        parts.append("LTK (hex): \(ltkHex)")
        parts.append("Firmware: \(firmwareVersion)")
        parts.append("Setup Progress: \(setupProgress)")
        
        if let activatedAt = activatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            parts.append("Activated: \(formatter.string(from: activatedAt))")
        }
        
        if let expiresAt = expiresAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            parts.append("Expires: \(formatter.string(from: expiresAt))")
        }
        
        parts.append("")
        parts.append("⚠️ Эти данные работают ТОЛЬКО на этом iPhone!")
        parts.append("⚠️ При восстановлении из полного бэкапа iPhone - работают на новом iPhone")
        
        return parts.joined(separator: "\n")
    }
}

