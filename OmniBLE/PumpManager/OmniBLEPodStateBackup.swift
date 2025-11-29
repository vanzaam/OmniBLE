//
//  OmniBLEPodStateBackup.swift
//  OmniBLE
//
//  Created for FreeAPS X on 2025-11-29.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
#if canImport(UIKit)
import UIKit
#endif

/// Структура для экспорта/импорта состояния пода DASH
/// ⚠️ ВАЖНО: Работает только на ТОМ ЖЕ iPhone (или при восстановлении из полного бэкапа iPhone)
public struct OmniBLEPodStateBackup: Codable {
    
    // MARK: - Metadata
    
    /// Версия формата бэкапа
    public let version: Int = 1
    
    /// Дата создания бэкапа
    public let createdAt: Date
    
    /// Модель iPhone (для проверки совместимости)
    public let deviceModel: String
    
    /// iOS версия
    public let iosVersion: String
    
    // MARK: - Critical Pod Data
    
    /// Pod Address (ID пода)
    public let address: UInt32
    
    /// Long Term Key (16 байт) - КРИТИЧНО!
    public let ltk: Data
    
    /// Bluetooth UUID peripheral - КРИТИЧНО!
    /// ⚠️ Должен совпадать с UUID в iOS Bluetooth-стеке
    public let bleIdentifier: String
    
    // MARK: - Session State
    
    /// Session encryption key (может быть nil если сессия не установлена)
    public let ck: Data?
    
    /// Nonce prefix для шифрования
    public let noncePrefix: Data?
    
    /// EAP sequence number (счетчик сессий)
    public let eapSeq: Int
    
    /// Message sequence number
    public let msgSeq: Int
    
    /// Nonce sequence number - КРИТИЧНО для шифрования!
    public let nonceSeq: Int
    
    /// Omnipod message counter
    public let messageNumber: Int
    
    // MARK: - Pod Information
    
    /// Firmware версия пода
    public let firmwareVersion: String
    
    /// BLE firmware версия
    public let bleFirmwareVersion: String
    
    /// Lot number
    public let lotNo: UInt32
    
    /// Lot sequence
    public let lotSeq: UInt32
    
    /// Product ID
    public let productId: UInt8
    
    /// Дата активации пода
    public let activatedAt: Date?
    
    /// Дата истечения срока пода
    public let expiresAt: Date?
    
    /// Статус установки пода
    public let setupProgress: Int
    
    /// Тип инсулина
    public let insulinType: String?
    
    // MARK: - Initialization
    
    public init(from podState: PodState) {
        self.createdAt = Date()
        self.deviceModel = Self.getDeviceModel()
        self.iosVersion = Self.getIOSVersion()
        
        // Critical data
        self.address = podState.address
        self.ltk = podState.ltk
        self.bleIdentifier = podState.bleIdentifier
        
        // Session state
        self.ck = podState.messageTransportState.ck
        self.noncePrefix = podState.messageTransportState.noncePrefix
        self.eapSeq = podState.messageTransportState.eapSeq
        self.msgSeq = podState.messageTransportState.msgSeq
        self.nonceSeq = podState.messageTransportState.nonceSeq
        self.messageNumber = podState.messageTransportState.messageNumber
        
        // Pod information
        self.firmwareVersion = podState.firmwareVersion
        self.bleFirmwareVersion = podState.bleFirmwareVersion
        self.lotNo = podState.lotNo
        self.lotSeq = podState.lotSeq
        self.productId = podState.productId
        self.activatedAt = podState.activatedAt
        self.expiresAt = podState.expiresAt
        self.setupProgress = podState.setupProgress.rawValue
        self.insulinType = podState.insulinType.brandName
    }
    
    // MARK: - Restore to PodState
    
    /// Восстанавливает PodState из бэкапа
    /// ⚠️ ВАЖНО: Работает только если bleIdentifier совпадает с iOS Bluetooth UUID!
    public func restoreToPodState() -> PodState? {
        guard let setupProgress = SetupProgress(rawValue: self.setupProgress) else {
            return nil
        }
        
        let messageTransportState = MessageTransportState(
            ck: self.ck,
            noncePrefix: self.noncePrefix,
            eapSeq: self.eapSeq,
            msgSeq: self.msgSeq,
            nonceSeq: self.nonceSeq, // КРИТИЧНО: восстанавливаем точное значение!
            messageNumber: self.messageNumber
        )
        
        let insulinType = InsulinType.allCases.first { $0.brandName == self.insulinType } ?? .novolog
        
        var podState = PodState(
            address: self.address,
            ltk: self.ltk,
            firmwareVersion: self.firmwareVersion,
            bleFirmwareVersion: self.bleFirmwareVersion,
            lotNo: self.lotNo,
            lotSeq: self.lotSeq,
            productId: self.productId,
            messageTransportState: messageTransportState,
            bleIdentifier: self.bleIdentifier,
            insulinType: insulinType
        )
        
        podState.activatedAt = self.activatedAt
        podState.expiresAt = self.expiresAt
        podState.setupProgress = setupProgress
        
        return podState
    }
    
    // MARK: - JSON Export/Import
    
    /// Экспортирует в JSON строку
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw BackupError.encodingFailed
        }
        return json
    }
    
    /// Импортирует из JSON строки
    public static func fromJSON(_ json: String) throws -> OmniBLEPodStateBackup {
        guard let data = json.data(using: .utf8) else {
            throw BackupError.invalidJSON
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OmniBLEPodStateBackup.self, from: data)
    }
    
    // MARK: - Validation
    
    /// Проверяет совместимость бэкапа с текущим устройством
    public func validateCompatibility() -> BackupValidationResult {
        let currentModel = Self.getDeviceModel()
        let currentIOS = Self.getIOSVersion()
        
        var warnings: [String] = []
        
        // Проверка модели устройства
        if self.deviceModel != currentModel {
            warnings.append("⚠️ Бэкап создан на другой модели iPhone: \(self.deviceModel) → \(currentModel)")
        }
        
        // Проверка iOS версии
        if self.iosVersion != currentIOS {
            warnings.append("⚠️ Бэкап создан на другой версии iOS: \(self.iosVersion) → \(currentIOS)")
        }
        
        // Проверка срока действия пода
        if let expiresAt = self.expiresAt, expiresAt < Date() {
            warnings.append("⚠️ Срок действия пода истек: \(expiresAt)")
        }
        
        // Проверка LTK
        if self.ltk.count != 16 {
            return .invalid(reason: "❌ Неверный размер LTK: \(self.ltk.count) байт (ожидается 16)")
        }
        
        // Проверка bleIdentifier
        if UUID(uuidString: self.bleIdentifier) == nil {
            return .invalid(reason: "❌ Неверный формат Bluetooth UUID: \(self.bleIdentifier)")
        }
        
        if warnings.isEmpty {
            return .valid
        } else {
            return .validWithWarnings(warnings: warnings)
        }
    }
    
    // MARK: - Helper Methods
    
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private static func getIOSVersion() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return "Unknown"
        #endif
    }
    
    // MARK: - Errors
    
    public enum BackupError: LocalizedError {
        case encodingFailed
        case invalidJSON
        case restorationFailed(reason: String)
        
        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Не удалось создать JSON из бэкапа"
            case .invalidJSON:
                return "Неверный формат JSON"
            case .restorationFailed(let reason):
                return "Не удалось восстановить состояние пода: \(reason)"
            }
        }
    }
    
    public enum BackupValidationResult {
        case valid
        case validWithWarnings(warnings: [String])
        case invalid(reason: String)
        
        public var isValid: Bool {
            switch self {
            case .valid, .validWithWarnings:
                return true
            case .invalid:
                return false
            }
        }
    }
}

