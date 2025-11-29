//
//  OmniBLEPodBackupView.swift
//  OmniBLE
//
//  Created for FreeAPS X on 2025-11-29.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OmniBLEPodBackupView: View {
    @ObservedObject var viewModel: OmniBLESettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            // MARK: - Информация о поде
            Section(header: Text("Информация о текущем поде")) {
                if let info = viewModel.getPodBackupInfo() {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "Pod ID", value: info.address)
                        InfoRow(title: "Bluetooth UUID", value: String(info.bleIdentifier.prefix(18)) + "...")
                        InfoRow(title: "Firmware", value: info.firmwareVersion)
                        InfoRow(title: "Статус", value: statusText(for: info.setupProgress))
                        
                        if let activatedAt = info.activatedAt {
                            InfoRow(title: "Активирован", value: formatDate(activatedAt))
                        }
                        
                        if let expiresAt = info.expiresAt {
                            InfoRow(title: "Истекает", value: formatDate(expiresAt))
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    
                    Button(action: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = info.fullDescription
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Копировать полную информацию")
                        }
                    }
                } else {
                    Text("Под не подключен")
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Экспорт бэкапа
            Section(header: Text("Экспорт бэкапа")) {
                Button(action: {
                    viewModel.exportBackup()
                    viewModel.showBackupSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Создать JSON бэкап")
                    }
                }
                
                if let error = viewModel.backupError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // MARK: - Импорт бэкапа
            Section(header: Text("Импорт бэкапа")) {
                Button(action: {
                    viewModel.showImportSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Восстановить из JSON")
                    }
                }
                
                if let error = viewModel.importError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // MARK: - Предупреждения
            Section(header: Text("⚠️ ВАЖНЫЕ ОГРАНИЧЕНИЯ")) {
                VStack(alignment: .leading, spacing: 12) {
                    WarningRow(
                        icon: "xmark.octagon.fill",
                        text: "НЕ РАБОТАЕТ: восстановление на \"чистой\" установке приложения или другом iPhone",
                        color: .red
                    )
                    
                    WarningRow(
                        icon: "checkmark.circle.fill",
                        text: "РАБОТАЕТ: в том же приложении на том же iPhone (после сбоя/переустановки без удаления данных)",
                        color: .green
                    )
                    
                    WarningRow(
                        icon: "checkmark.circle.fill",
                        text: "РАБОТАЕТ: при восстановлении ПОЛНОГО бэкапа iPhone (iTunes/Finder) на новый iPhone",
                        color: .green
                    )
                    
                    WarningRow(
                        icon: "info.circle.fill",
                        text: "Причина: Omnipod DASH использует криптографическую привязку к Bluetooth UUID устройства",
                        color: .blue
                    )
                }
            }
            
            // MARK: - Как это работает
            Section(header: Text("Техническое объяснение")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Почему бэкап НЕ работает на другом iPhone:")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("1. Omnipod DASH использует EAP-AKA протокол")
                    Text("2. При каждом подключении создаётся НОВАЯ сессия")
                    Text("3. Счётчики (eapSeq, nonceSeq) должны совпадать с подом")
                    Text("4. При переносе данных - счётчики рассинхронизируются")
                    Text("5. Под отклоняет команды с неверными счётчиками ❌")
                    
                    Text("\nКогда полный бэкап iPhone работает:")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                    
                    Text("1. iOS восстанавливает ВСЁ состояние Bluetooth")
                    Text("2. Bluetooth UUID пода остаётся ТЕМ ЖЕ")
                    Text("3. Приложение восстанавливается с актуальными счётчиками")
                    Text("4. Под принимает команды → работает! ✅")
                    
                    Text("\nЭкспорт полезен для:")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    
                    Text("• Сохранения информации о поде (ID, firmware, даты)")
                    Text("• Диагностики проблем с подключением")
                    Text("• Резервного копирования на том же устройстве")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Бэкап пода")
        .sheet(isPresented: $viewModel.showBackupSheet) {
            BackupExportSheet(
                json: viewModel.backupJSON,
                onCopy: viewModel.copyBackupToClipboard,
                onDismiss: { viewModel.showBackupSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showImportSheet) {
            BackupImportSheet(
                json: $viewModel.importJSON,
                onImport: viewModel.importBackup,
                onDismiss: { viewModel.showImportSheet = false }
            )
        }
        .alert(isPresented: $viewModel.showBackupSuccess) {
            Alert(
                title: Text("Бэкап создан"),
                message: Text("JSON бэкап успешно создан и готов к копированию"),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $viewModel.showImportSuccess) {
            Alert(
                title: Text("Бэкап восстановлен"),
                message: Text("Состояние пода успешно восстановлено. Приложение попытается переподключиться к поду."),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func statusText(for progress: SetupProgress) -> String {
        switch progress {
        case .addressAssigned: return "Адрес назначен"
        case .podPaired: return "Под сопряжен"
        case .startingPrime: return "Начало заполнения"
        case .priming: return "Заполнение"
        case .settingInitialBasalSchedule: return "Установка базала"
        case .initialBasalScheduleSet: return "Базал установлен"
        case .startingInsertCannula: return "Начало установки канюли"
        case .cannulaInserting: return "Установка канюли"
        case .completed: return "Активирован ✅"
        case .activationTimeout: return "Таймаут активации"
        case .podIncompatible: return "Несовместимый под"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct WarningRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
        }
    }
}

struct BackupExportSheet: View {
    let json: String
    let onCopy: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("JSON Бэкап создан")
                    .font(.headline)
                
                ScrollView {
                    Text(json)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                #if canImport(UIKit)
                Button(action: {
                    onCopy()
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Копировать в буфер обмена")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                #endif
                
                Text("⚠️ Сохраните этот JSON в безопасном месте")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding()
            .navigationTitle("Экспорт бэкапа")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct BackupImportSheet: View {
    @Binding var json: String
    let onImport: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Предупреждение сверху
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("ВНИМАНИЕ!")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Text("Восстановление работает ТОЛЬКО если:")
                            .font(.subheadline)
                            .bold()
                        
                        Text("✅ Это ТО ЖЕ приложение на ТОМ ЖЕ iPhone")
                        Text("✅ Или iPhone восстановлен из ПОЛНОГО бэкапа iTunes/Finder")
                        
                        Text("\n❌ НЕ РАБОТАЕТ:")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.red)
                        
                        Text("• На другом iPhone без полного бэкапа")
                        Text("• На \"чистой\" установке приложения")
                        Text("• При ручном переносе данных")
                    }
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("Вставьте JSON бэкап")
                        .font(.headline)
                    
                    TextEditor(text: $json)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 200)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    #if canImport(UIKit)
                    Button(action: {
                        if let clipboardString = UIPasteboard.general.string {
                            json = clipboardString
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Вставить из буфера обмена")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    #endif
                    
                    Button(action: {
                        onImport()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Восстановить из бэкапа")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(json.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(json.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Импорт бэкапа")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

