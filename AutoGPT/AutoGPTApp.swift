//
//  AutoGPTApp.swift
//  AutoGPT
//
//  Created by Arun Mishra on 11/18/25.
//

import SwiftUI

@main
struct AutoGPTApp: App {
    @State private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: container.mainViewModel)
                .task {
                    // Request permissions on app launch
                    let permissions = await container.checkAndRequestPermissions()

                    if !permissions.microphone {
                        print("⚠️ Microphone permission not granted")
                    }

                    if !permissions.accessibility {
                        print("⚠️ Accessibility permission not granted")
                        print("Please grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
                    }
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    container.mainViewModel.createNewSession()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
