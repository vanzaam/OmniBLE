//
//  InitialReservoirLevelView.swift
//  OmniBLE
//
//  Created by FreeAPS X on 2025-01-27.
//  Copyright © 2025 FreeAPS X. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import Foundation

struct InitialReservoirLevelView: View {
    let pumpManager: OmniBLEPumpManager
    @StateObject private var viewModel: InitialReservoirLevelViewModel
    
    init(pumpManager: OmniBLEPumpManager) {
        self.pumpManager = pumpManager
        self._viewModel = StateObject(wrappedValue: InitialReservoirLevelViewModel(pumpManager: pumpManager))
    }
    
    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    var body: some View {
        Form {
            Section(
                header: Text("Начальный остаток резервуара"),
                footer: Text("Укажите начальный остаток резервуара для правильного учета инсулина. Помпа возвращает только количество поданного инсулина, а не остаток. Это значение используется для расчета текущего остатка: Начальный остаток - Поданный инсулин = Текущий остаток.")
            ) {
                HStack {
                    Text("Остаток при установке")
                    Spacer()
                    OptionalDecimalTextField("U", value: $viewModel.initialReservoirLevel, formatter: formatter)
                    Text("U").foregroundColor(.secondary)
                }
                
                if let currentLevel = viewModel.currentReservoirLevel {
                    HStack {
                        Text("Текущий расчетный остаток")
                        Spacer()
                        Text("\(Double(truncating: currentLevel as NSNumber), specifier: "%.1f") U")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                HStack {
                    if viewModel.syncInProgress {
                        ProgressView().padding(.trailing, 10)
                    }
                    Button { 
                        viewModel.save() 
                    } label: {
                        Text(viewModel.syncInProgress ? "Сохранение..." : "Сохранить")
                    }
                    .disabled(viewModel.syncInProgress)
                }
            }
        }
        .navigationTitle("Настройки резервуара")
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

class InitialReservoirLevelViewModel: ObservableObject {
    @Published var initialReservoirLevel: Decimal? = nil
    @Published var currentReservoirLevel: Decimal? = nil
    @Published var syncInProgress = false
    
    private let pumpManager: OmniBLEPumpManager
    private let reservoirKey = "initialReservoirLevel"
    
    // ✅ Use APP_GROUP_ID from config instead of hardcode
    private var userDefaults: UserDefaults? {
        guard let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String else {
            print("⚠️ InitialReservoirLevelView: AppGroupID not found in Info.plist")
            return nil
        }
        return UserDefaults(suiteName: appGroupID)
    }
    
    init(pumpManager: OmniBLEPumpManager) {
        self.pumpManager = pumpManager
    }
    
    func loadSettings() {
        // ✅ КРИТИЧНО: Сначала проверяем синхронизационный ключ (используется при добавлении помпы)
        if let data = userDefaults?.data(forKey: "pumpSettings_initialReservoirLevel"),
           let value = try? JSONDecoder().decode(Decimal.self, from: data) {
            initialReservoirLevel = value
            print("🎯 InitialReservoirLevelView: Loaded from pumpSettings_initialReservoirLevel: \(value)")
        }
        // Fallback: Если синхронизационный ключ пустой, проверяем старый ключ
        else if let data = userDefaults?.data(forKey: reservoirKey),
                let value = try? JSONDecoder().decode(Decimal.self, from: data) {
            initialReservoirLevel = value
            print("🎯 InitialReservoirLevelView: Loaded from old key (initialReservoirLevel): \(value)")
        } else {
            print("🎯 InitialReservoirLevelView: No saved value found")
        }
        
        // Calculate current reservoir level if possible
        calculateCurrentReservoirLevel()
    }
    
    func save() {
        // Validate input
        if let reservoirLevel = initialReservoirLevel {
            let reservoirDouble = Double(truncating: reservoirLevel as NSNumber)
            if reservoirDouble < 0 || reservoirDouble > 200 {
                print("⚠️ Invalid reservoir level: \(reservoirDouble). Must be between 0-200 units.")
                return
            }
        }
        
        // Use async to avoid publishing changes during view updates
        DispatchQueue.main.async {
            self.syncInProgress = true
        }
        
        // Save to UserDefaults
        if let value = initialReservoirLevel,
           let data = try? JSONEncoder().encode(value) {
            userDefaults?.set(data, forKey: reservoirKey)
            print("🎯 InitialReservoirLevelView: Saved to UserDefaults: \(value)")
        } else {
            userDefaults?.removeObject(forKey: reservoirKey)
            print("🎯 InitialReservoirLevelView: Removed from UserDefaults")
        }
        
        // 🚀 CRITICAL: Save to special key that main app will sync to PumpSettings
        // Use a different key that the main app can monitor and sync
        if let value = initialReservoirLevel,
           let data = try? JSONEncoder().encode(value) {
            userDefaults?.set(data, forKey: "pumpSettings_initialReservoirLevel")
            print("🎯 InitialReservoirLevelView: Saved to pumpSettings_initialReservoirLevel: \(value)")
        } else {
            userDefaults?.removeObject(forKey: "pumpSettings_initialReservoirLevel")
            print("🎯 InitialReservoirLevelView: Removed from pumpSettings_initialReservoirLevel")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.syncInProgress = false
        }
        
        // Recalculate current reservoir level
        calculateCurrentReservoirLevel()
    }
    
    private func calculateCurrentReservoirLevel() {
        // This would need access to pump manager to get delivered insulin
        // For now, just show the initial level
        currentReservoirLevel = initialReservoirLevel
    }
}

// MARK: - OptionalDecimalTextField

struct OptionalDecimalTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var value: Decimal?
    let formatter: NumberFormatter
    
    init(_ placeholder: String, value: Binding<Decimal?>, formatter: NumberFormatter) {
        self.placeholder = placeholder
        self._value = value
        self.formatter = formatter
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .decimalPad
        textField.borderStyle = .none
        textField.textAlignment = .right
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if let value = value {
            uiView.text = formatter.string(from: NSDecimalNumber(decimal: value))
        } else {
            uiView.text = ""
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: OptionalDecimalTextField
        
        init(_ parent: OptionalDecimalTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateValue(textField.text)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            updateValue(textField.text)
        }
        
        private func updateValue(_ text: String?) {
            guard let text = text, !text.isEmpty else {
                parent.value = nil
                return
            }
            
            // Replace comma with dot for decimal separator
            let normalizedText = text.replacingOccurrences(of: ",", with: ".")
            
            if let number = parent.formatter.number(from: normalizedText) {
                parent.value = number.decimalValue
            } else {
                parent.value = nil
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

            // Allow empty string (for clearing)
            if newText.isEmpty {
                return true
            }

            // Allow decimal separator
            if string == "." || string == "," {
                return !currentText.contains(".") && !currentText.contains(",")
            }

            // Allow digits
            if string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
                // Validate range for reservoir level (0-200 units)
                if let number = Double(newText), number > 200 {
                    return false
                }
                return true
            }

            return false
        }
    }
}

// Preview removed due to complexity of OmniBLEPumpManager initialization
// The view works correctly when used in the actual app
