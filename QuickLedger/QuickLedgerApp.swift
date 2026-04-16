//
// QuickLedgerApp.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import SwiftUI

@main
struct QuickLedgerApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
