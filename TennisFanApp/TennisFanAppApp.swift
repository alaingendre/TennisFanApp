//
//  TennisFanAppApp.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import SwiftUI
import SwiftData

@main
struct TennisFanAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Player.self, Game.self, Attendance.self])
    }
}
