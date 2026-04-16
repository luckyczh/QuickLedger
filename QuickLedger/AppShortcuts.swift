//
// AppShortcuts.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import AppIntents

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "快速记账"
    static let description = IntentDescription("从快捷指令快速带入金额到记账页。")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "备注")
    var note: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutDraftStore.save(amount: amount, note: note)
        return .result(dialog: "已将金额带入记账页，打开 App 后确认保存即可。")
    }
}

struct QuickLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "快速记账 \(.applicationName)",
                "记一笔 \(.applicationName)"
            ],
            shortTitle: "快速记账",
            systemImageName: "plus.circle.fill"
        )
    }
}
