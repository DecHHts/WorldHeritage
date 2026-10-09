import Foundation
import SwiftUI
import UIKit

/// 离线图片包：按国家把遗产图片下载到本机
final class OfflineStore: ObservableObject {
    static let shared = OfflineStore()

    @Published private(set) var downloaded: Set<String>
    /// 正在下载的国家 → 进度 0…1
    @Published private(set) var progress: [String: Double] = [:]

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("offline", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private init() {
        downloaded = Set(UserDefaults.standard.stringArray(forKey: "offline.countries") ?? [])
    }

    private func persist() {
        UserDefaults.standard.set(Array(downloaded), forKey: "offline.countries")
    }

    static func fileURL(for remote: URL) -> URL {
        dir.appendingPathComponent(remote.lastPathComponent)
    }

    /// 已离线保存的图片；没有则返回 nil
    static func localImage(for remote: URL) -> UIImage? {
        let f = fileURL(for: remote)
        guard FileManager.default.fileExists(atPath: f.path) else { return nil }
        return UIImage(contentsOfFile: f.path)
    }

    func isDownloading(_ iso: String) -> Bool { progress[iso] != nil }

    @MainActor
    func download(_ iso: String) async {
        if progress[iso] != nil { return }
        let urls = DataStore.shared.sites(in: iso).compactMap { $0.imageURL }
        if urls.isEmpty { return }
        progress[iso] = 0
        var done = 0
        var saved = 0
        for url in urls {
            let target = OfflineStore.fileURL(for: url)
            if FileManager.default.fileExists(atPath: target.path) {
                saved += 1
            } else if let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      UIImage(data: data) != nil {
                try? data.write(to: target, options: .atomic)
                saved += 1
            }
            done += 1
            progress[iso] = Double(done) / Double(urls.count)
        }
        progress[iso] = nil
        if saved > 0 {
            downloaded.insert(iso)
            persist()
        }
    }

    func remove(_ iso: String) {
        downloaded.remove(iso)
        persist()
        // 跨国遗产的图片若仍属于其他已下载国家，则保留
        var keep = Set<String>()
        for other in downloaded {
            for s in DataStore.shared.sites(in: other) {
                if let u = s.imageURL { keep.insert(u.lastPathComponent) }
            }
        }
        for s in DataStore.shared.sites(in: iso) {
            guard let u = s.imageURL, !keep.contains(u.lastPathComponent) else { continue }
            try? FileManager.default.removeItem(at: OfflineStore.fileURL(for: u))
        }
    }

    /// 离线包占用的空间（字节）
    var totalBytes: Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: OfflineStore.dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        var sum = 0
        for f in files {
            sum += (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return sum
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
}
