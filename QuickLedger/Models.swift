//
// Models.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import Foundation
enum RecordType: String, CaseIterable, Codable {
    case expense
    case income

    var title: String {
        switch self {
        case .expense:
            "支出"
        case .income:
            "收入"
        }
    }
}

struct LedgerCategory: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var type: RecordType
    var icon: String
    var isBuiltIn: Bool
    var isArchived: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: RecordType,
        icon: String,
        isBuiltIn: Bool,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

struct TransactionRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var type: RecordType
    var amount: Decimal
    var note: String
    var occurredAt: Date
    var source: String
    var createdAt: Date
    var updatedAt: Date
    var categoryId: UUID?

    init(
        id: UUID = UUID(),
        type: RecordType,
        amount: Decimal,
        note: String = "",
        occurredAt: Date = .now,
        source: String = "manual",
        category: LedgerCategory?,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.note = note
        self.occurredAt = occurredAt
        self.source = source
        self.categoryId = category?.id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
