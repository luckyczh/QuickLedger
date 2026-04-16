//
// ContentView.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            QuickEntryView()
                .tabItem {
                    Label("记一笔", systemImage: "plus.circle")
                }

            TransactionsView()
                .tabItem {
                    Label("明细", systemImage: "list.bullet")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

private struct QuickEntryView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var amountText = ""
    @State private var noteText = ""
    @State private var selectedType: RecordType = .expense
    @State private var selectedCategoryID: UUID?
    @State private var selectedDate: Date = .now
    @State private var showMore = false
    @State private var source = "manual"
    @State private var showSavedBanner = false

    private var currentCategories: [LedgerCategory] {
        store.categories.filter { $0.type == selectedType && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快速录入")
                            .font(.headline)

                        Picker("类型", selection: $selectedType) {
                            ForEach(RecordType.allCases, id: \.rawValue) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedType) { _, _ in
                            updateDefaultCategoryIfNeeded()
                        }

                        TextField("金额", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(currentCategories, id: \.id) { category in
                                    categoryChip(category)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Button(showMore ? "收起更多" : "更多选项") {
                        showMore.toggle()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if showMore {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("补充信息")
                                .font(.headline)
                            DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                            TextField("备注", text: $noteText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Button("保存") {
                        saveRecord()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .overlay(alignment: .top) {
                if showSavedBanner {
                    Text("已保存")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.9), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if source == "shortcut" {
                    Text("来自快捷指令")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
            .onAppear {
                consumeShortcutDraftIfNeeded()
                updateDefaultCategoryIfNeeded()
            }
        }
    }

    private func categoryChip(_ category: LedgerCategory) -> some View {
        let selected = selectedCategoryID == category.id
        return Button {
            selectedCategoryID = category.id
        } label: {
            Label(category.name, systemImage: category.icon)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.gray.opacity(0.15), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func updateDefaultCategoryIfNeeded() {
        guard currentCategories.contains(where: { $0.id == selectedCategoryID }) else {
            selectedCategoryID = currentCategories.first?.id
            return
        }
    }

    private func consumeShortcutDraftIfNeeded() {
        guard let draft = ShortcutDraftStore.readAndClear() else {
            return
        }
        amountText = String(format: "%.2f", draft.amount)
        noteText = draft.note
        selectedType = draft.type
        selectedDate = draft.date
        source = draft.source
        showMore = !draft.note.isEmpty
    }

    private func saveRecord() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: normalized), amount > 0 else {
            return
        }

        let category = currentCategories.first(where: { $0.id == selectedCategoryID })
        let record = TransactionRecord(
            type: selectedType,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: selectedDate,
            source: source,
            category: category
        )
        store.saveRecord(
            amount: record.amount,
            type: record.type,
            categoryId: record.categoryId,
            note: record.note,
            date: record.occurredAt,
            source: record.source
        )

        amountText = ""
        noteText = ""
        selectedDate = .now
        source = "manual"
        showSavedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSavedBanner = false
        }
    }
}

private struct TransactionsView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.records, id: \.id) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.categoryName(for: record.categoryId))
                            Spacer()
                            let symbol = record.type == .expense ? "-" : "+"
                            Text("\(symbol)\(record.amount.formattedCurrency)")
                                .foregroundStyle(record.type == .expense ? .red : .green)
                        }
                        Text(record.occurredAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !record.note.isEmpty {
                            Text(record.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    store.deleteRecords(at: indexSet)
                }
            }
            .navigationTitle("明细")
        }
    }
}

private struct StatsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedMonth = Date()

    private var monthRecords: [TransactionRecord] {
        let calendar = Calendar.current
        guard
            let interval = calendar.dateInterval(of: .month, for: selectedMonth)
        else {
            return []
        }
        return store.records.filter {
            $0.type == .expense &&
            interval.contains($0.occurredAt)
        }
    }

    private var totalExpense: Decimal {
        monthRecords.reduce(0) { $0 + $1.amount }
    }

    private var grouped: [(name: String, amount: Decimal)] {
        let dictionary = Dictionary(grouping: monthRecords) { store.categoryName(for: $0.categoryId) }
            .mapValues { list in
                list.reduce(0) { $0 + $1.amount }
            }
        return dictionary
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("本月支出") {
                    Text(totalExpense.formattedCurrency)
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                }

                Section("分类占比") {
                    if grouped.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(grouped, id: \.name) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(row.name)
                                    Spacer()
                                    Text(row.amount.formattedCurrency)
                                }
                                let ratio = ratioValue(amount: row.amount, total: totalExpense)
                                ProgressView(value: ratio)
                                    .tint(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    monthStepper
                }
            }
        }
    }

    private var monthStepper: some View {
        HStack(spacing: 12) {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            Text(selectedMonth.formatted(.dateTime.year().month()))
                .font(.subheadline.monospacedDigit())
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private func ratioValue(amount: Decimal, total: Decimal) -> Double {
        guard total > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue
        return max(0, min(1, ratio))
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var categoryName = ""
    @State private var categoryType: RecordType = .expense

    var body: some View {
        NavigationStack {
            Form {
                Section("新增自定义分类") {
                    TextField("分类名", text: $categoryName)
                    Picker("类型", selection: $categoryType) {
                        ForEach(RecordType.allCases, id: \.rawValue) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("添加分类") {
                        store.addCategory(name: categoryName, type: categoryType)
                        categoryName = ""
                    }
                }

                Section("分类管理") {
                    ForEach(store.categories, id: \.id) { category in
                        HStack {
                            Label(category.name, systemImage: category.icon)
                            Spacer()
                            if !category.isBuiltIn {
                                Toggle("归档", isOn: binding(for: category))
                                    .labelsHidden()
                            } else {
                                Text("内置")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("同步") {
                    Text("当前为本地模式，已预留云同步扩展点。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }

    private func binding(for category: LedgerCategory) -> Binding<Bool> {
        Binding(
            get: { category.isArchived },
            set: { newValue in
                store.setCategoryArchived(category.id, archived: newValue)
            }
        )
    }
}

private extension Decimal {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "¥0.00"
    }
}

