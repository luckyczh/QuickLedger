//
// AppServices.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import Foundation

enum ShortcutDraftStore {
    static let amountKey = "shortcut_draft_amount"
    static let noteKey = "shortcut_draft_note"
    static let typeKey = "shortcut_draft_type"
    static let dateKey = "shortcut_draft_date"
    static let sourceKey = "shortcut_draft_source"

    static func save(amount: Double, note: String?) {
        let defaults = UserDefaults.standard
        defaults.set(amount, forKey: amountKey)
        defaults.set(note, forKey: noteKey)
        defaults.set(RecordType.expense.rawValue, forKey: typeKey)
        defaults.set(Date(), forKey: dateKey)
        defaults.set("shortcut", forKey: sourceKey)
    }

    static func readAndClear() -> DraftPayload? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: amountKey) != nil else {
            return nil
        }

        let amount = defaults.double(forKey: amountKey)
        let note = defaults.string(forKey: noteKey) ?? ""
        let rawType = defaults.string(forKey: typeKey) ?? RecordType.expense.rawValue
        let date = defaults.object(forKey: dateKey) as? Date ?? .now
        let source = defaults.string(forKey: sourceKey) ?? "manual"

        defaults.removeObject(forKey: amountKey)
        defaults.removeObject(forKey: noteKey)
        defaults.removeObject(forKey: typeKey)
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: sourceKey)

        return DraftPayload(
            amount: amount,
            note: note,
            type: RecordType(rawValue: rawType) ?? .expense,
            date: date,
            source: source
        )
    }
}

struct DraftPayload {
    let amount: Double
    let note: String
    let type: RecordType
    let date: Date
    let source: String
}

enum BootstrapService {}
