//
//  PodSetupView.swift
//  OmniBLE
//
//  Created by Pete Schwamb on 5/17/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
#if canImport(UIKit)
import UIKit
#endif

struct PodSetupView: View {
    @Environment(\.dismissAction) private var dismiss
    
    private struct AlertIdentifier: Identifiable {
        enum Choice {
            case skipOnboarding
        }
        var id: Choice
    }
    @State private var alertIdentifier: AlertIdentifier?
    @State private var showRestoreSheet = false
    @State private var restoreJSON = ""
    @State private var restoreError: String?
    @State private var isRestoring = false

    let nextAction: () -> Void
    let allowDebugFeatures: Bool
    let skipOnboarding: () -> Void
    let restoreFromBackup: ((String) -> Result<Void, Error>)?
    
    var body: some View {
        VStack(alignment: .leading) {
            close
            ScrollView {
                content
            }
            Spacer()
            continueButton
                .padding(.bottom)
            if restoreFromBackup != nil {
                restoreButton
                    .padding(.bottom)
            }
        }
        .padding(.horizontal)
        .navigationBarHidden(true)
        .alert(item: $alertIdentifier) { alert in
            switch alert.id {
            case .skipOnboarding:
                return skipOnboardingAlert
            }
        }
        .sheet(isPresented: $showRestoreSheet) {
            restoreSheet
        }
    }
    
    @ViewBuilder
    private var close: some View {
        HStack {
            Spacer()
            cancelButton
        }
        .padding(.top)
    }
        
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
                .padding(.top, 5)
                .onLongPressGesture(minimumDuration: 2) {
                    didLongPressOnTitle()
                }
            Divider()
            bodyText
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }

    @ViewBuilder
    private var title: some View {
        Text(LocalizedString("Pod Setup", comment: "Title for PodSetupView"))
            .font(.largeTitle)
            .bold()
            .padding(.vertical)
    }
    
    @ViewBuilder
    private var bodyText: some View {
        Text(LocalizedString("You will now begin the process of configuring your reminders, filling your Pod with insulin, pairing to your device and placing it on your body.", comment: "bodyText for PodSetupView"))
    }
    
    private var cancelButton: some View {
        Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
            self.dismiss()
        })
    }

    private var continueButton: some View {
        Button(LocalizedString("Continue", comment: "Text for continue button on PodSetupView"), action: nextAction)
            .buttonStyle(ActionButtonStyle())
    }
    
    private var restoreButton: some View {
        Button(action: { showRestoreSheet = true }) {
            Text("Восстановить из бэкапа")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(.secondary))
    }
    
    @ViewBuilder
    private var restoreSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
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
                        
                        Text("\n❌ НЕ РАБОТАЕТ на \"чистой\" установке!")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("Вставьте JSON бэкап пода:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $restoreJSON)
                        .frame(height: 150)
                        .border(Color.gray, width: 1)
                    
                    if let error = restoreError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Вставить из буфера") {
                            pasteFromClipboard()
                        }
                        .buttonStyle(ActionButtonStyle(.secondary))
                        .disabled(isRestoring)
                        
                        Button("Восстановить") {
                            performRestore()
                        }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(isRestoring || restoreJSON.isEmpty)
                    }
                    
                    if isRestoring {
                        ProgressView("Восстанавливаем под...")
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Восстановление пода")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        showRestoreSheet = false
                        restoreJSON = ""
                        restoreError = nil
                    }
                }
            }
        }
    }
    
    private func pasteFromClipboard() {
        #if os(iOS)
        if let clipboardString = UIPasteboard.general.string {
            restoreJSON = clipboardString
            restoreError = nil
        } else {
            restoreError = "Буфер обмена пуст или не содержит текст"
        }
        #else
        restoreError = "Вставка из буфера доступна только на iOS"
        #endif
    }
    
    private func performRestore() {
        guard let restoreHandler = restoreFromBackup else {
            restoreError = "Функция восстановления недоступна"
            return
        }
        
        isRestoring = true
        restoreError = nil
        
        // Даем UI время обновиться перед тяжелой операцией
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = restoreHandler(restoreJSON)
            
            DispatchQueue.main.async {
                isRestoring = false
                
                switch result {
                case .success:
                    // Успешно восстановлено - coordinator сам закроет UI
                    showRestoreSheet = false
                    restoreJSON = ""
                    restoreError = nil
                    // НЕ вызываем dismiss() - coordinator закроет через completionDelegate
                case .failure(let error):
                    restoreError = error.localizedDescription
                }
            }
        }
    }
    
    private var skipOnboardingAlert: Alert {
        Alert(title: Text("Skip Omnipod Onboarding?"),
              message: Text("Are you sure you want to skip Omnipod Onboarding?"),
              primaryButton: .cancel(),
              secondaryButton: .destructive(Text("Yes"), action: skipOnboarding))
    }
    
    private func didLongPressOnTitle() {
        if allowDebugFeatures {
            alertIdentifier = AlertIdentifier(id: .skipOnboarding)
        }
    }

}

struct PodSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PodSetupView(nextAction: {}, allowDebugFeatures: true, skipOnboarding: {}, restoreFromBackup: nil)
    }
}
