import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Site

struct SitePoint: Codable, Hashable {
    let c: String
    let la: Double
    let lo: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: la, longitude: lo)
    }
}

struct Site: Codable, Identifiable, Hashable {
    let id: Int
    /// 简体中文名称
    let n: String
    /// 繁体中文名称
    let nt: String
    /// 英文名称
    let e: String
    /// 简体中文简介
    let d: String
    /// 繁体中文简介
    let dt: String
    /// 英文简介
    let de: String
    let nj: String
    let dj: String
    let nk: String
    let dk: String
    /// 简介是否为编译译文（官方暂无中文）
    let t: Bool
    /// 列入年份
    let y: Int
    /// 类别 C / N / M
    let k: String
    /// 入选标准
    let cr: [String]
    /// 是否列入濒危名录
    let dg: Bool
    /// 所属地区
    let r: [String]
    /// 国家 ISO 代码
    let cc: [String]
    /// 每个国家一个代表坐标
    let p: [SitePoint]
    /// 是否跨国遗产
    let tn: Bool
    let img: String

    static func == (lhs: Site, rhs: Site) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var category: HeritageCategory { HeritageCategory(rawValue: k) ?? .cultural }

    var coordinate: CLLocationCoordinate2D {
        p.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    func coordinate(in iso: String) -> CLLocationCoordinate2D {
        (p.first { $0.c == iso } ?? p.first)?.coordinate ?? coordinate
    }

    /// 按当前语言显示的名称（日语、韩语暂用英文官方名称）
    var name: String {
        switch L10n.lang {
        case .hans: return n
        case .hant: return nt
        case .ja: return nj
        case .ko: return nk
        default: return e
        }
    }

    /// 副标题：中文界面显示英文名，其他语言不重复显示
    var altName: String? {
        switch L10n.lang {
        case .hans, .hant, .ja, .ko: return e
        default: return nil
        }
    }

    var summary: String {
        switch L10n.lang {
        case .hans: return d
        case .hant: return dt
        case .ja: return dj
        case .ko: return dk
        default: return de.isEmpty ? d : de
        }
    }

    var flags: String {
        cc.prefix(5).map { flagEmoji($0) }.joined() + (cc.count > 5 ? "…" : "")
    }

    private var countryNames: [String] {
        if cc.isEmpty { return [T("耶路撒冷（由约旦申报）")] }
        return cc.map { DataStore.shared.country($0)?.name ?? $0 }
    }

    /// 完整的国家列表
    var countriesFull: String {
        countryNames.joined(separator: T("、"))
    }

    /// 列表里用的简短国家文本
    var countryText: String {
        let parts = countryNames
        if parts.count > 4 {
            return T("%@ 等 %d 国", parts.prefix(3).joined(separator: T("、")), parts.count)
        }
        return parts.joined(separator: T("、"))
    }

    var yearText: String { T("%@ 年", String(y)) }

    var imageURL: URL? { URL(string: img) }
    var officialURL: URL? {
        let code = (L10n.lang == .hans || L10n.lang == .hant) ? "zh" : "en"
        return URL(string: "https://whc.unesco.org/\(code)/list/\(id)")
    }
}

enum HeritageCategory: String, CaseIterable, Identifiable {
    case cultural = "C"
    case natural = "N"
    case mixed = "M"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cultural: return T("文化遗产")
        case .natural: return T("自然遗产")
        case .mixed: return T("混合遗产")
        }
    }

    var shortTitle: String {
        switch self {
        case .cultural: return T("文化")
        case .natural: return T("自然")
        case .mixed: return T("混合")
        }
    }

    var symbol: String {
        switch self {
        case .cultural: return "building.columns.fill"
        case .natural: return "leaf.fill"
        case .mixed: return "mountain.2.fill"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .cultural: return UIColor(red: 0.80, green: 0.42, blue: 0.20, alpha: 1)
        case .natural: return UIColor(red: 0.18, green: 0.58, blue: 0.38, alpha: 1)
        case .mixed: return UIColor(red: 0.45, green: 0.36, blue: 0.75, alpha: 1)
        }
    }

    var color: Color { Color(uiColor) }
}

func flagEmoji(_ iso: String) -> String {
    guard iso.count == 2 else { return "🏳️" }
    var s = ""
    for u in iso.uppercased().unicodeScalars {
        if let scalar = UnicodeScalar(127397 + u.value) {
            s.unicodeScalars.append(scalar)
        }
    }
    return s
}

enum Criteria {
    static func localized(_ c: String) -> String {
        guard let zh = text[c] else { return "" }
        return T(zh)
    }

    static let text: [String: String] = [
        "i": "代表人类创造性天才的杰作。",
        "ii": "展现一段时期内或某一文化区域内，人类价值观在建筑、技术、纪念性艺术、城镇规划或景观设计方面的重要交流。",
        "iii": "为现存或已消逝的文明或文化传统提供独特的、至少是特殊的见证。",
        "iv": "是展现人类历史重要阶段的建筑物、建筑或技术整体、景观的杰出范例。",
        "v": "是代表一种或多种文化、或人类与环境相互作用的传统聚落、土地利用或海洋利用的杰出范例，尤其是在不可逆变化影响下变得脆弱时。",
        "vi": "与具有突出普遍意义的事件、现行传统、思想、信仰、文学艺术作品有直接或实质的联系。",
        "vii": "包含绝妙的自然现象，或具有罕见自然美和美学价值的地区。",
        "viii": "是代表地球演化史重要阶段的突出例证，包括生命记录、地貌演变中的重要地质过程或显著的地质地貌特征。",
        "ix": "是代表陆地、淡水、海岸和海洋生态系统及动植物群落演变、发展中重要生态和生物过程的突出例证。",
        "x": "是生物多样性原地保护最重要的自然栖息地，包括具有突出普遍价值的濒危物种栖息地。"
    ]
}

// MARK: - Country

struct CountryPolygon {
    let ring: [CLLocationCoordinate2D]
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let area: Double

    func contains(lat: Double, lon: Double) -> Bool {
        if lat < minLat || lat > maxLat || lon < minLon || lon > maxLon { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let yi = ring[i].latitude, xi = ring[i].longitude
            let yj = ring[j].latitude, xj = ring[j].longitude
            if (yi > lat) != (yj > lat) {
                let x = (xj - xi) * (lat - yi) / (yj - yi) + xi
                if lon < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }
}

struct Country: Identifiable, Hashable {
    let iso: String
    let zh: String
    let zt: String
    let en: String
    let ja: String
    let ko: String
    let region: MKCoordinateRegion
    let polygons: [CountryPolygon]

    var id: String { iso }
    var flag: String { flagEmoji(iso) }

    var name: String {
        switch L10n.lang {
        case .hans: return zh
        case .hant: return zt
        case .en: return en
        case .ja: return ja
        case .ko: return ko
        }
    }

    static func == (lhs: Country, rhs: Country) -> Bool { lhs.iso == rhs.iso }
    func hash(into hasher: inout Hasher) { hasher.combine(iso) }
}

// MARK: - Store

final class DataStore {
    static let shared = DataStore()

    let sites: [Site]
    let countries: [Country]
    let regions: [String]
    private let siteByID: [Int: Site]
    private let countryByISO: [String: Country]
    private let sitesByISO: [String: [Site]]

    private init() {
        var loadedSites: [Site] = []
        if let url = Bundle.main.url(forResource: "sites", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Site].self, from: data) {
            loadedSites = decoded
        }
        sites = loadedSites

        var byID: [Int: Site] = [:]
        var byISO: [String: [Site]] = [:]
        var regionSet: [String] = []
        for s in loadedSites {
            byID[s.id] = s
            for c in s.cc { byISO[c, default: []].append(s) }
            for r in s.r where !regionSet.contains(r) { regionSet.append(r) }
        }
        siteByID = byID
        sitesByISO = byISO
        regions = regionSet.sorted()

        var loadedCountries: [Country] = []
        if let url = Bundle.main.url(forResource: "countries", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in raw {
                guard let iso = item["iso"] as? String,
                      let zh = item["zh"] as? String,
                      let en = item["en"] as? String,
                      let zt = item["zt"] as? String,
                      let ja = item["ja"] as? String,
                      let ko = item["ko"] as? String,
                      let rg = item["rg"] as? [NSNumber], rg.count == 4,
                      let polys = item["polys"] as? [[[NSNumber]]] else { continue }
                var polygons: [CountryPolygon] = []
                polygons.reserveCapacity(polys.count)
                for ring in polys {
                    var coords: [CLLocationCoordinate2D] = []
                    coords.reserveCapacity(ring.count)
                    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
                    for pt in ring where pt.count >= 2 {
                        let lon = pt[0].doubleValue
                        let lat = pt[1].doubleValue
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        minLat = min(minLat, lat); maxLat = max(maxLat, lat)
                        minLon = min(minLon, lon); maxLon = max(maxLon, lon)
                    }
                    if coords.count < 3 { continue }
                    polygons.append(CountryPolygon(ring: coords, minLat: minLat, maxLat: maxLat,
                                                   minLon: minLon, maxLon: maxLon,
                                                   area: (maxLat - minLat) * (maxLon - minLon)))
                }
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: rg[0].doubleValue, longitude: rg[1].doubleValue),
                    span: MKCoordinateSpan(latitudeDelta: min(rg[2].doubleValue, 150),
                                           longitudeDelta: min(rg[3].doubleValue, 300)))
                loadedCountries.append(Country(iso: iso, zh: zh, zt: zt, en: en, ja: ja, ko: ko, region: region, polygons: polygons))
            }
        }
        countries = loadedCountries
        var cByISO: [String: Country] = [:]
        for c in loadedCountries { cByISO[c.iso] = c }
        countryByISO = cByISO
    }

    func site(_ id: Int) -> Site? { siteByID[id] }
    func country(_ iso: String) -> Country? { countryByISO[iso] }
    func sites(in iso: String) -> [Site] { sitesByISO[iso] ?? [] }

    func sites(in iso: String, layer: HeatLayer) -> [Site] {
        let limit = DataStore.yearLimit ?? Int.max
        return sites(in: iso).filter { $0.y <= limit && layer.contains($0) }
    }

    /// 时间轴年份上限（由设置同步过来）
    static var yearLimit: Int? = nil

    func sites(layer: HeatLayer) -> [Site] {
        if let limit = DataStore.yearLimit {
            return sites.filter { $0.y <= limit && layer.contains($0) }
        }
        return layer == .all ? sites : sites.filter { layer.contains($0) }
    }

    var yearRange: ClosedRange<Int> {
        let ys = sites.map { $0.y }
        return (ys.min() ?? 1978)...(ys.max() ?? 2025)
    }

    func countryCount(layer: HeatLayer) -> Int {
        var set = Set<String>()
        for s in sites(layer: layer) { for c in s.cc { set.insert(c) } }
        return set.count
    }

    /// 某个图层的热力点（每项遗产在每个国家取一个代表点）
    func heatPoints(layer: HeatLayer) -> [MKMapPoint] {
        var pts: [MKMapPoint] = []
        for s in sites(layer: layer) {
            for p in s.p { pts.append(MKMapPoint(p.coordinate)) }
        }
        return pts
    }

    /// 点击位置所在国家：取包含该点且外接矩形最小的多边形，找不到时回退到最近的遗产所在国
    func country(at coord: CLLocationCoordinate2D) -> Country? {
        let lat = coord.latitude, lon = coord.longitude
        var best: Country?
        var bestArea = Double.greatestFiniteMagnitude
        for c in countries {
            for poly in c.polygons where poly.area < bestArea {
                if poly.contains(lat: lat, lon: lon) {
                    best = c
                    bestArea = poly.area
                }
            }
        }
        if let best = best { return best }

        var nearest: String?
        var nearestD = 1.2 * 1.2
        let k = cos(lat * .pi / 180)
        for s in sites {
            for p in s.p where !p.c.isEmpty {
                let dy = p.la - lat
                let dx = (p.lo - lon) * k
                let d = dx * dx + dy * dy
                if d < nearestD {
                    nearestD = d
                    nearest = p.c
                }
            }
        }
        if let iso = nearest { return countryByISO[iso] }
        return nil
    }
}
