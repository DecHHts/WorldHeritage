import Foundation
import UserNotifications
import SwiftUI

/// 通知点击、小组件点击后要打开的遗产
final class DeepLink: ObservableObject {
    static let shared = DeepLink()
    @Published var site: Site? = nil

    func open(id: Int) {
        if let s = DataStore.shared.site(id) {
            DispatchQueue.main.async { self.site = s }
        }
    }

    /// worldheritage://site/123
    func handle(_ url: URL) {
        guard url.scheme == "worldheritage", url.host == "site",
              let id = Int(url.lastPathComponent) else { return }
        open(id: id)
    }
}

/// “今日遗产”：全 App 和小组件用同一种算法按日期取一项
enum DailyPick {
    static func index(for date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let days = Int(floor(date.timeIntervalSince1970 / 86400 + Double(TimeZone.current.secondsFromGMT(for: date)) / 86400))
        return abs(days &* 7919) % count
    }

    static func site(for date: Date) -> Site? {
        let all = DataStore.shared.sites
        if all.isEmpty { return nil }
        return all[index(for: date, count: all.count)]
    }
}

/// 本地通知：每日推荐、到达提醒
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()

    func start() {
        center.delegate = self
        if UserDefaults.standard.bool(forKey: "notify.daily") { scheduleDaily() }
    }

    func requestPermission(_ done: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    /// 预排未来 14 天、每天上午 9 点的“今日遗产”
    func scheduleDaily() {
        cancelDaily()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  fire > Date(),
                  let site = DailyPick.site(for: day) else { continue }
            let content = UNMutableNotificationContent()
            content.title = T("今日遗产")
            content.body = "\(site.name) · \(site.countryText)"
            content.userInfo = ["site": site.id]
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "daily.\(offset)", content: content, trigger: trigger))
        }
    }

    func cancelDaily() {
        center.removePendingNotificationRequests(withIdentifiers: (0..<14).map { "daily.\($0)" })
    }

    func notifyArrival(_ site: Site, checkedIn: Bool) {
        let content = UNMutableNotificationContent()
        content.title = T("你在世界遗产附近")
        content.body = checkedIn ? T("%@ · 已自动记为去过", site.name) : site.name
        content.sound = .default
        content.userInfo = ["site": site.id]
        center.add(UNNotificationRequest(identifier: "arrival.\(site.id)", content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let id = response.notification.request.content.userInfo["site"] as? Int {
            DeepLink.shared.open(id: id)
        }
        completionHandler()
    }
}
