import Foundation
import SwiftUI

/// 想去 / 去过。本地保存在 UserDefaults；开启 iCloud 键值存储能力后，
/// 会通过同一个 Apple ID 的 iCloud 在设备间自动同步（未开启时云端调用不生效，不影响本地使用）。
final class FavoritesStore: ObservableObject {
    @Published private(set) var wish: Set<Int>
    @Published private(set) var visited: Set<Int>

    private let wishKey = "favorites.wish"
    private let visitedKey = "favorites.visited"
    private let local = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    init() {
        wish = Set(UserDefaults.standard.array(forKey: "favorites.wish") as? [Int] ?? [])
        visited = Set(UserDefaults.standard.array(forKey: "favorites.visited") as? [Int] ?? [])

        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main) { [weak self] _ in
            self?.pullFromCloud(replace: true)
        }
        cloud.synchronize()
        // 首次启动：把云端已有记录并入本机
        pullFromCloud(replace: false)
        FavoritesStore.current = self
        for id in visited { JournalStore.shared.ensure(id) }
        shareCounts()
    }

    /// 供图层筛选等非界面代码读取
    static weak var current: FavoritesStore?

    private func shareCounts() {
        Shared.defaults.set(visited.count, forKey: "visitedCount")
        Shared.defaults.set(wish.count, forKey: "wishCount")
        Shared.defaults.set(DataStore.shared.sites.count, forKey: "totalCount")
        Shared.reloadWidgets()
    }

    deinit {
        if let observer = observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func cloudSet(_ key: String) -> Set<Int>? {
        guard let arr = cloud.array(forKey: key) else { return nil }
        return Set(arr.compactMap { ($0 as? NSNumber)?.intValue })
    }

    private func pullFromCloud(replace: Bool) {
        // iCloud 同步属于订阅功能
        guard Pro.isPro else { return }
        let w = cloudSet(wishKey)
        let v = cloudSet(visitedKey)
        if w == nil && v == nil { return }
        if replace {
            if let w = w { wish = w }
            if let v = v { visited = v }
            local.set(Array(wish), forKey: wishKey)
            local.set(Array(visited), forKey: visitedKey)
        } else {
            wish.formUnion(w ?? [])
            visited.formUnion(v ?? [])
            save()
        }
    }

    private func save() {
        local.set(Array(wish), forKey: wishKey)
        local.set(Array(visited), forKey: visitedKey)
        if Pro.isPro {
            cloud.set(Array(wish), forKey: wishKey)
            cloud.set(Array(visited), forKey: visitedKey)
        }
        shareCounts()
    }

    /// 订阅生效后调用：把本机记录与云端合并
    func syncNow() {
        guard Pro.isPro else { return }
        cloud.synchronize()
        pullFromCloud(replace: false)
    }

    /// 免费版“想去”是否已到上限
    var wishLimitReached: Bool { !Pro.isPro && wish.count >= Pro.freeWishLimit }

    func isWish(_ site: Site) -> Bool { wish.contains(site.id) }
    func isVisited(_ site: Site) -> Bool { visited.contains(site.id) }

    /// 返回 false 表示免费版已到上限，没有加入
    @discardableResult
    func toggleWish(_ site: Site) -> Bool {
        if wish.contains(site.id) {
            wish.remove(site.id)
        } else {
            if wishLimitReached { return false }
            wish.insert(site.id)
        }
        save()
        return true
    }

    func toggleVisited(_ site: Site) {
        if visited.contains(site.id) {
            visited.remove(site.id)
            JournalStore.shared.remove(site.id)
        } else {
            visited.insert(site.id)
            JournalStore.shared.ensure(site.id)
        }
        save()
    }

    func markVisited(_ site: Site) {
        if !visited.contains(site.id) { toggleVisited(site) }
    }

    var wishSites: [Site] {
        wish.compactMap { DataStore.shared.site($0) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var visitedSites: [Site] {
        visited.compactMap { DataStore.shared.site($0) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var visitedCountryCount: Int {
        var set = Set<String>()
        for s in visitedSites { for c in s.cc { set.insert(c) } }
        return set.count
    }
}
