//
// AppShortcuts.swift
// QuickLedger
//
// Created by 茵陈 on 2026/4/16.
//

import AppIntents
import Vision
import UIKit
import SwiftUI

// 主要的记账 Intent - 接收截图
struct AddExpenseFromScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "识别账单"
    static let description = IntentDescription("从截屏中识别金额并记账")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "内容", default: "")
    var content: String

    @Parameter(title: "图片", supportedTypeIdentifiers: ["public.image"])
    var image: IntentFile

    @Parameter(title: "备注", default: "")
    var note: String

    @Parameter(title: "版本", default: "1.0.0")
    var version: String

    @Parameter(title: "运行时显示", default: true)
    var showWhenRun: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let imageData = image.data
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw NSError(domain: "QuickLedger", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取图片"])
        }

        let recognizedText = try await recognizeText(from: cgImage)
        guard let amount = extractAmount(from: recognizedText) else {
            throw NSError(domain: "QuickLedger", code: 3, userInfo: [NSLocalizedDescriptionKey: "未识别到有效金额"])
        }
        let category = recognizeCategory(from: recognizedText)
        let finalNote = note.isEmpty ? (content.isEmpty ? "" : content) : note

        // 直接保存记录，不需要打开 App
        try await saveRecordDirectly(amount: amount, note: finalNote, categoryName: category)

        return .result(
            dialog: "识别到金额 ¥\(String(format: "%.2f", amount))，分类：\(category)，已保存。",
            view: AmountSnippetView(amount: amount, note: finalNote.isEmpty ? nil : finalNote)
        )
    }

    private func saveRecordDirectly(amount: Double, note: String, categoryName: String) async throws {
        // 使用 App Group 共享容器（如果配置了）
        let fileManager = FileManager.default
        let containerURL: URL

        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.quickledger.app") {
            containerURL = groupURL
            print("✅ 使用 App Group: \(groupURL.path)")
        } else {
            // 回退到文档目录
            containerURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            print("⚠️ 使用文档目录: \(containerURL.path)")
        }

        let recordFileURL = containerURL.appendingPathComponent("records.json")
        let categoryFileURL = containerURL.appendingPathComponent("categories.json")
        print("📁 记录文件路径: \(recordFileURL.path)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // 读取分类
        var categories: [LedgerCategory] = []
        if let data = try? Data(contentsOf: categoryFileURL),
           let decoded = try? decoder.decode([LedgerCategory].self, from: data) {
            categories = decoded
        }

        // 查找匹配的分类
        let matchedCategory = categories.first { $0.name == categoryName && $0.type == .expense }

        // 读取现有记录
        var records: [TransactionRecord] = []
        if let data = try? Data(contentsOf: recordFileURL),
           let decoded = try? decoder.decode([TransactionRecord].self, from: data) {
            records = decoded
            print("📖 读取到 \(records.count) 条现有记录")
        } else {
            print("📝 没有现有记录，创建新文件")
        }

        // 创建新记录
        let newRecord = TransactionRecord(
            type: .expense,
            amount: Decimal(amount),
            note: note,
            occurredAt: .now,
            source: "shortcut",
            category: matchedCategory
        )

        // 插入到开头
        records.insert(newRecord, at: 0)
        print("💾 准备保存 \(records.count) 条记录，分类：\(categoryName)")

        // 保存
        if let data = try? encoder.encode(records) {
            do {
                try data.write(to: recordFileURL, options: .atomic)
                print("✅ 保存成功")
            } catch {
                print("❌ 保存失败: \(error)")
                throw error
            }
        } else {
            print("❌ 编码失败")
            throw NSError(domain: "QuickLedger", code: 4, userInfo: [NSLocalizedDescriptionKey: "编码失败"])
        }
    }

    private func recognizeText(from image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: NSError(domain: "QuickLedger", code: 2, userInfo: [NSLocalizedDescriptionKey: "未识别到文字"]))
                    return
                }

                var allText = ""
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    allText += topCandidate.string + " "
                }

                continuation.resume(returning: allText)
            }

            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func recognizeCategory(from text: String) -> String {
        let categoryKeywords: [String: [String]] = [
            "餐饮": ["餐", "饭", "食", "吃", "喝", "咖啡", "奶茶", "外卖", "美团", "饿了么", "肯德基", "麦当劳", "星巴克"],
            "交通": ["交通", "打车", "滴滴", "出租", "地铁", "公交", "停车", "加油", "高速"],
            "购物": ["购物", "淘宝", "京东", "拼多多", "超市", "商场", "买"],
            "居家": ["水电", "房租", "物业", "家具", "装修", "维修"]
        ]

        let lowercaseText = text.lowercased()

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercaseText.contains(keyword) {
                    return category
                }
            }
        }

        return "购物" // 默认分类
    }

    private func extractAmount(from text: String) -> Double? {
        let patterns = [
            "¥\\s*([0-9]+\\.?[0-9]*)",
            "([0-9]+\\.?[0-9]*)\\s*元",
            "\\$\\s*([0-9]+\\.?[0-9]*)",
            "RMB\\s*([0-9]+\\.?[0-9]*)",
            "([0-9]+\\.[0-9]{2})(?![0-9])",
            "([0-9]{1,6})(?![0-9])"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: text) {
                    let amountString = String(text[swiftRange])
                    if let amount = Double(amountString), amount > 0 && amount < 1000000 {
                        return amount
                    }
                }
            }
        }

        return nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("识别账单") {
            \.$content
            \.$image
            \.$note
            \.$version
            \.$showWhenRun
        }
    }
}

// 辅助 Intent - 手动输入金额
struct AddExpenseManualIntent: AppIntent {
    static let title: LocalizedStringResource = "快速记账"
    static let description = IntentDescription("手动输入金额快速记账")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "备注", default: "")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutDraftStore.save(amount: amount, note: note.isEmpty ? nil : note)
        return .result(dialog: "已将金额 ¥\(String(format: "%.2f", amount)) 带入记账页")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("记账 ¥\(\.$amount)") {
            \.$note
        }
    }
}

struct AmountSnippetView: View {
    let amount: Double
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "yensign.circle.fill")
                    .foregroundColor(.green)
                Text("识别金额")
                    .font(.headline)
            }

            Text("¥\(String(format: "%.2f", amount))")
                .font(.title)
                .bold()

            if let note = note, !note.isEmpty {
                Text("备注: \(note)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct QuickLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseFromScreenshotIntent(),
            phrases: [
                "识别账单 \(.applicationName)",
                "快速记账 \(.applicationName)"
            ],
            shortTitle: "识别账单",
            systemImageName: "doc.text.viewfinder"
        )
    }
}
