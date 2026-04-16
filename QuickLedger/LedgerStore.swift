//
// LedgerStore.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import Foundation

@MainActor
final class LedgerStore: ObservableObject {
    @Published private(set) var categories: [LedgerCategory] = []
    @Published private(set) var records: [TransactionRecord] = []

    private let categoryFileName = "categories.json"
    private let recordFileName = "records.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        loadData()
        ensureBuiltInCategories()
    }

    func saveRecord(
        amount: Decimal,
        type: RecordType,
        categoryId: UUID?,
        note: String,
        date: Date,
        source: String
    ) {
        let record = TransactionRecord(
            type: type,
            amount: amount,
            note: note,
            occurredAt: date,
            source: source,
            category: categories.first(where: { $0.id == categoryId })
        )
        records.insert(record, at: 0)
        persistRecords()
    }

    func deleteRecords(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persistRecords()
    }

    func addCategory(name: String, type: RecordType) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !categories.contains(where: { $0.type == type && $0.name == trimmed }) else {
            return
        }
        categories.append(LedgerCategory(name: trimmed, type: type, icon: "tag", isBuiltIn: false))
        categories.sort { $0.createdAt < $1.createdAt }
        persistCategories()
    }

    func setCategoryArchived(_ id: UUID, archived: Bool) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].isArchived = archived
        persistCategories()
    }

    func categoryName(for id: UUID?) -> String {
        guard let id else { return "未分类" }
        return categories.first(where: { $0.id == id })?.name ?? "未分类"
    }

    private func loadData() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if let categoryData = try? Data(contentsOf: fileURL(fileName: categoryFileName)),
           let decodedCategories = try? decoder.decode([LedgerCategory].self, from: categoryData) {
            categories = decodedCategories
        }

        if let recordData = try? Data(contentsOf: fileURL(fileName: recordFileName)),
           let decodedRecords = try? decoder.decode([TransactionRecord].self, from: recordData) {
            records = decodedRecords.sorted { $0.occurredAt > $1.occurredAt }
        }
    }

    private func ensureBuiltInCategories() {
        guard categories.isEmpty else { return }
        categories = [
            LedgerCategory(name: "餐饮", type: .expense, icon: "fork.knife", isBuiltIn: true),
            LedgerCategory(name: "交通", type: .expense, icon: "car", isBuiltIn: true),
            LedgerCategory(name: "购物", type: .expense, icon: "bag", isBuiltIn: true),
            LedgerCategory(name: "居家", type: .expense, icon: "house", isBuiltIn: true),
            LedgerCategory(name: "其他支出", type: .expense, icon: "ellipsis.circle", isBuiltIn: true),
            LedgerCategory(name: "工资", type: .income, icon: "banknote", isBuiltIn: true),
            LedgerCategory(name: "奖金", type: .income, icon: "gift", isBuiltIn: true),
            LedgerCategory(name: "其他收入", type: .income, icon: "plus.circle", isBuiltIn: true)
        ]
        persistCategories()
    }

    private func persistCategories() {
        guard let data = try? encoder.encode(categories) else { return }
        try? data.write(to: fileURL(fileName: categoryFileName), options: .atomic)
    }

    private func persistRecords() {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL(fileName: recordFileName), options: .atomic)
    }

    private func fileURL(fileName: String) -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent(fileName)
    }
}
