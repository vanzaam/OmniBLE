//
//  InitialReservoirSetupView.swift
//  OmniBLE
//
//  Created by FreeAPS X on 2025-11-03.
//  Copyright © 2025 FreeAPS X. All rights reserved.
//

import SwiftUI
import LoopKitUI
import LoopKit
import HealthKit

struct InitialReservoirSetupView: View {
    
    // Allowed Initial Reservoir values (50-200 Units in steps of 5)
    private static let allowedInitialReservoirValues = Array(stride(from: 50, through: 200, by: 5))

    @State var initialReservoirValue: Int
    
    public var valueChanged: ((_ value: Int) -> Void)?
    public var continueButtonTapped: (() -> Void)?
    public var cancelButtonTapped: (() -> Void)?

    var insulinQuantityFormatter = QuantityFormatter(for: .internationalUnit())

    func formatValue(_ value: Int) -> String {
        return insulinQuantityFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: Double(value))) ?? ""
    }

    var body: some View {
        GuidePage(content: {
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedString("Укажите сколько единиц инсулина вы залили в новый под.\n\nПрокрутите колесо для выбора количества единиц (50 до 200), которое вы залили в под при его установке.", comment: "Description text on InitialReservoirSetupView"))
                Divider()
                HStack {
                    Text(LocalizedString("Начальный остаток", comment: "Label text for initial reservoir value row"))
                    Spacer()
                    Text(formatValue(initialReservoirValue))
                }
                picker
            }
            .padding(.vertical, 8)
        }) {
            VStack {
                Button(action: {
                    continueButtonTapped?()
                }) {
                    Text(LocalizedString("Далее", comment: "Text of continue button on InitialReservoirSetupView"))
                        .actionButtonStyle(.primary)
                }
            }
            .padding()
        }
        .navigationBarTitle(LocalizedString("Начальный остаток", comment: "navigation bar title for initial reservoir"), displayMode: .automatic)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedString("Отмена", comment: "Cancel button title"), action: {
                    cancelButtonTapped?()
                })
            }
        }
    }
    
    private var picker: some View {
        Picker("", selection: $initialReservoirValue) {
            ForEach(InitialReservoirSetupView.allowedInitialReservoirValues, id: \.self) { value in
                Text(formatValue(value))
            }
        }.pickerStyle(WheelPickerStyle())
        .onChange(of: initialReservoirValue) { value in
            valueChanged?(value)
        }

    }

}

struct InitialReservoirSetupView_Previews: PreviewProvider {
    static var previews: some View {
        InitialReservoirSetupView(initialReservoirValue: 200)
    }
}

