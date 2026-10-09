import Foundation
import SwiftUI
import UIKit

/// 一次打卡：日期 + 一句话笔记（照片单独存文件）
struct JournalEntry: Codable, Hashable {
    var date: Date
    var note: String
}

/// 打卡记录，保存在本机文稿目录
final class JournalStore: ObservableObject {
    static let shared = JournalStore()

    @Published private(set) var entries: [Int: JournalEntry] = [:]
    /// 照片变化时加一，让界面刷新
    @Published private(set) var photoVersion = 0

    private let dir: URL
    private let file: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("journal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("journal.json")
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([String: JournalEntry].self, from: data) {
            var map: [Int: JournalEntry] = [:]
            for (k, v) in decoded { if let id = Int(k) { map[id] = v } }
            entries = map
        }
    }

    private func save() {
        var map: [String: JournalEntry] = [:]
        for (k, v) in entries { map[String(k)] = v }
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: file, options: .atomic)
        }
    }

    func entry(_ id: Int) -> JournalEntry? { entries[id] }

    func ensure(_ id: Int) {
        if entries[id] == nil {
            entries[id] = JournalEntry(date: Date(), note: "")
            save()
        }
    }

    func remove(_ id: Int) {
        entries[id] = nil
        try? FileManager.default.removeItem(at: photoURL(id))
        photoVersion += 1
        save()
    }

    func setDate(_ id: Int, _ date: Date) {
        var e = entries[id] ?? JournalEntry(date: date, note: "")
        e.date = date
        entries[id] = e
        save()
    }

    func setNote(_ id: Int, _ note: String) {
        var e = entries[id] ?? JournalEntry(date: Date(), note: note)
        e.note = note
        entries[id] = e
        save()
    }

    func photoURL(_ id: Int) -> URL { dir.appendingPathComponent("\(id).jpg") }

    func photo(_ id: Int) -> UIImage? {
        UIImage(contentsOfFile: photoURL(id).path)
    }

    func setPhoto(_ id: Int, data: Data) {
        guard let image = UIImage(data: data) else { return }
        // 压到长边 1600 以内再保存
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let jpg = resized.jpegData(compressionQuality: 0.82) {
            try? jpg.write(to: photoURL(id), options: .atomic)
            photoVersion += 1
        }
    }

    func removePhoto(_ id: Int) {
        try? FileManager.default.removeItem(at: photoURL(id))
        photoVersion += 1
    }

    /// 有打卡记录的年份，新的在前
    func years(visited: Set<Int>) -> [Int] {
        let cal = Calendar.current
        var set = Set<Int>()
        for id in visited {
            if let e = entries[id] { set.insert(cal.component(.year, from: e.date)) }
        }
        return set.sorted(by: >)
    }

    func sites(inYear year: Int, visited: Set<Int>) -> [Site] {
        let cal = Calendar.current
        var list: [(Site, Date)] = []
        for id in visited {
            if let e = entries[id], cal.component(.year, from: e.date) == year,
               let s = DataStore.shared.site(id) {
                list.append((s, e.date))
            }
        }
        return list.sorted { $0.1 < $1.1 }.map { $0.0 }
    }
}
