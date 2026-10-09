import Foundation
import CoreLocation
import SwiftUI

/// 推荐 / 转盘 / 行程共用的筛选条件
struct TripCriteria: Equatable {
    var days: Int = 5
    var category: HeritageCategory? = nil
    var region: String? = nil
    var countryISO: String? = nil
    /// 距出发地的最大直线距离（公里）
    var maxKm: Double? = nil
    var seasonal = false
    var excludeVisited = true
}

enum Planner {
    static let distanceOptions: [Double] = [300, 1000, 3000, 6000]

    static func km(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let la1 = a.latitude * .pi / 180, la2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    /// 遗产到某点的最近距离（跨国遗产取最近的一处）
    static func km(_ site: Site, from origin: CLLocationCoordinate2D) -> Double {
        var best = Double.greatestFiniteMagnitude
        for p in site.p { best = min(best, km(p.coordinate, origin)) }
        return best
    }

    /// 按纬度粗略估算当前月份是否适合出行：温带、寒带避开当地冬季，热带不作判断
    static func inSeason(_ site: Site, month: Int) -> Bool {
        let lat = site.coordinate.latitude
        if abs(lat) < 23.5 { return true }
        let warmNorth = (4...10).contains(month)
        return lat > 0 ? warmNorth : !(5...9).contains(month)
    }

    static func candidates(_ c: TripCriteria, origin: CLLocationCoordinate2D?,
                           visited: Set<Int>) -> [Site] {
        let month = Calendar.current.component(.month, from: Date())
        return DataStore.shared.sites.filter { s in
            if let cat = c.category, s.category != cat { return false }
            if let region = c.region, !s.r.contains(region) { return false }
            if let iso = c.countryISO, !s.cc.contains(iso) { return false }
            if c.excludeVisited && visited.contains(s.id) { return false }
            if c.seasonal && !inSeason(s, month: month) { return false }
            if let maxKm = c.maxKm, let origin = origin, km(s, from: origin) > maxKm { return false }
            return true
        }
    }

    /// 选一组地理上连贯的遗产：先挑一个周边候选最多的“落脚点”，再取它附近的若干项
    static func recommend(_ c: TripCriteria, origin: CLLocationCoordinate2D?,
                          wish: Set<Int>, visited: Set<Int>) -> [Site] {
        let pool = candidates(c, origin: origin, visited: visited)
        if pool.isEmpty { return [] }
        let want = min(max(c.days, 1), 10)
        if pool.count <= want { return order(pool, from: origin) }

        // 候选太多时抽样评估落脚点
        let anchors = pool.count > 160 ? Array(pool.shuffled().prefix(160)) : pool
        var scored: [(Site, Double)] = []
        for a in anchors {
            var near = 0.0
            for b in pool where km(a.coordinate, b.coordinate) < 350 {
                near += wish.contains(b.id) ? 2.5 : 1
            }
            var score = min(near, Double(want) * 1.6) + Double.random(in: 0..<2.5)
            if wish.contains(a.id) { score += 2 }
            if let origin = origin, c.maxKm == nil {
                // 没限定距离时略微偏向近处
                score -= min(km(a, from: origin) / 4000, 2)
            }
            scored.append((a, score))
        }
        guard let anchor = scored.max(by: { $0.1 < $1.1 })?.0 else { return [] }
        let picked = pool
            .map { ($0, km(anchor.coordinate, $0.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(want)
            .map { $0.0 }
        return order(Array(picked), from: origin)
    }

    /// 最近邻排序：从出发地（没有则从第一项）开始，每次去最近的下一项
    static func order(_ sites: [Site], from origin: CLLocationCoordinate2D?) -> [Site] {
        var rest = sites
        var result: [Site] = []
        var here: CLLocationCoordinate2D
        if let origin = origin {
            here = origin
        } else if !rest.isEmpty {
            // 没有出发地时，从离这组遗产中心最远的一端出发，避免来回折返
            let n = Double(rest.count)
            let center = CLLocationCoordinate2D(latitude: rest.map { $0.coordinate.latitude }.reduce(0, +) / n,
                                                longitude: rest.map { $0.coordinate.longitude }.reduce(0, +) / n)
            var far = rest[0]
            var farD = -1.0
            for s in rest {
                let d = km(s.coordinate, center)
                if d > farD { farD = d; far = s }
            }
            here = far.coordinate
        } else {
            return []
        }
        while !rest.isEmpty {
            var bi = 0
            var bd = Double.greatestFiniteMagnitude
            for (i, s) in rest.enumerated() {
                let d = km(s.coordinate, here)
                if d < bd { bd = d; bi = i }
            }
            let next = rest.remove(at: bi)
            result.append(next)
            here = next.coordinate
        }
        return result
    }

    /// 相邻两站之间的直线距离
    static func legs(_ sites: [Site]) -> [Double] {
        guard sites.count > 1 else { return [] }
        return (1..<sites.count).map { km(sites[$0 - 1].coordinate, sites[$0].coordinate) }
    }

    /// 每项遗产算一天，相邻两站超过 800 公里另加一天路程
    static func estimatedDays(_ sites: [Site]) -> Int {
        sites.count + legs(sites).filter { $0 > 800 }.count
    }

    /// 每站的第几天（从 0 开始）
    static func dayOffsets(_ sites: [Site]) -> [Int] {
        var offsets: [Int] = []
        var day = 0
        let l = legs(sites)
        for i in sites.indices {
            if i > 0 { day += l[i - 1] > 800 ? 2 : 1 }
            offsets.append(day)
        }
        return offsets
    }

    static func kmText(_ km: Double) -> String {
        NearbyView.format(km * 1000)
    }

    /// 不依赖模型的推荐理由
    static func reason(_ site: Site, origin: CLLocationCoordinate2D?, wish: Set<Int>) -> String {
        var parts: [String] = [site.category.title, T("%@ 年列入", String(site.y))]
        if let origin = origin { parts.append(T("距你约 %@", kmText(km(site, from: origin)))) }
        if wish.contains(site.id) { parts.append(T("在你的想去清单里")) }
        if site.dg { parts.append(T("濒危")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 行程

struct Trip: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var siteIDs: [Int]
    var start: Date? = nil
    var created = Date()

    var sites: [Site] { siteIDs.compactMap { DataStore.shared.site($0) } }
}

final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip] = []

    private let file: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        file = docs.appendingPathComponent("trips.json")
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(trips) {
            try? data.write(to: file, options: .atomic)
        }
    }

    func trip(_ id: UUID) -> Trip? { trips.first { $0.id == id } }

    @discardableResult
    func add(name: String, sites: [Site]) -> Trip {
        let t = Trip(name: name, siteIDs: sites.map { $0.id })
        trips.insert(t, at: 0)
        save()
        return t
    }

    func update(_ trip: Trip) {
        if let i = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[i] = trip
            save()
        }
    }

    func delete(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        save()
    }

    /// 生成日历文件（.ics）：每项遗产一个全天日程
    static func icsFile(for trip: Trip) -> URL? {
        let sites = trip.sites
        if sites.isEmpty { return nil }
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: trip.start ?? Date())
        let dayFmt = DateFormatter()
        dayFmt.calendar = cal
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        dayFmt.dateFormat = "yyyyMMdd"
        let stampFmt = DateFormatter()
        stampFmt.locale = Locale(identifier: "en_US_POSIX")
        stampFmt.timeZone = TimeZone(identifier: "UTC")
        stampFmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let stamp = stampFmt.string(from: Date())

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: ";", with: "\\;")
                .replacingOccurrences(of: ",", with: "\\,")
                .replacingOccurrences(of: "\n", with: "\\n")
        }

        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//WorldHeritage//Trip//EN", "CALSCALE:GREGORIAN"]
        let offsets = Planner.dayOffsets(sites)
        for (i, s) in sites.enumerated() {
            guard let day = cal.date(byAdding: .day, value: offsets[i], to: start),
                  let next = cal.date(byAdding: .day, value: 1, to: day) else { continue }
            lines += [
                "BEGIN:VEVENT",
                "UID:\(trip.id.uuidString)-\(s.id)@worldheritage",
                "DTSTAMP:\(stamp)",
                "DTSTART;VALUE=DATE:\(dayFmt.string(from: day))",
                "DTEND;VALUE=DATE:\(dayFmt.string(from: next))",
                "SUMMARY:\(esc(s.name))",
                "LOCATION:\(esc(s.countriesFull))",
                "GEO:\(s.coordinate.latitude);\(s.coordinate.longitude)",
                "DESCRIPTION:\(esc(trip.name))",
                "END:VEVENT"
            ]
        }
        lines.append("END:VCALENDAR")
        let text = lines.joined(separator: "\r\n") + "\r\n"
        let safe = trip.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe.isEmpty ? "trip" : safe).ics")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
