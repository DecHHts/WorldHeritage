import Foundation
import CoreLocation

/// 个人定位；订阅用户可开启“到达提醒”，走到遗产附近时通知并自动打卡
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus

    /// 到达提醒开关（订阅功能）
    @Published var alertsOn: Bool {
        didSet {
            UserDefaults.standard.set(alertsOn, forKey: "alerts.on")
            if alertsOn { manager.requestAlwaysAuthorization() }
            refreshRegions()
        }
    }

    /// 到达时自动记为去过
    @Published var autoCheckIn: Bool {
        didSet { UserDefaults.standard.set(autoCheckIn, forKey: "alerts.auto") }
    }

    /// 判定为“到达”的距离（米）
    static let arrivalRadius = 3000.0

    private let manager = CLLocationManager()
    private var regionAnchor: CLLocation?

    override init() {
        status = manager.authorizationStatus
        alertsOn = UserDefaults.standard.bool(forKey: "alerts.on")
        autoCheckIn = UserDefaults.standard.object(forKey: "alerts.auto") as? Bool ?? true
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 200
    }

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    private var alertsActive: Bool { alertsOn && Pro.isPro }

    /// 首次调用会弹出系统授权；已授权则开始更新位置
    func request() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        location = last
        guard alertsActive else { return }
        checkArrival(at: last)
        if regionAnchor == nil || last.distance(from: regionAnchor!) > 20_000 {
            refreshRegions()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: 到达提醒

    private func distance(_ site: Site, from here: CLLocation) -> Double {
        var best = Double.greatestFiniteMagnitude
        for p in site.p {
            let d = here.distance(from: CLLocation(latitude: p.la, longitude: p.lo))
            if d < best { best = d }
        }
        return best
    }

    private func arrive(_ site: Site) {
        let key = "alerts.notified"
        var notified = Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
        if notified.contains(site.id) { return }
        notified.insert(site.id)
        UserDefaults.standard.set(Array(notified), forKey: key)

        var checked = false
        if autoCheckIn, let fav = FavoritesStore.current, !fav.isVisited(site) {
            fav.markVisited(site)
            checked = true
        }
        Notifier.shared.notifyArrival(site, checkedIn: checked)
    }

    private func checkArrival(at here: CLLocation) {
        for s in DataStore.shared.sites where distance(s, from: here) <= LocationManager.arrivalRadius {
            arrive(s)
        }
    }

    /// 系统最多同时监控 20 个区域：始终保留离当前位置最近的 18 项
    private func refreshRegions() {
        for r in manager.monitoredRegions where r.identifier.hasPrefix("site.") {
            manager.stopMonitoring(for: r)
        }
        guard alertsActive, let here = location,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            regionAnchor = nil
            return
        }
        regionAnchor = here
        let nearest = DataStore.shared.sites
            .map { ($0, distance($0, from: here)) }
            .sorted { $0.1 < $1.1 }
            .prefix(18)
        for (site, _) in nearest {
            var best = site.p.first
            var bestD = Double.greatestFiniteMagnitude
            for p in site.p {
                let d = here.distance(from: CLLocation(latitude: p.la, longitude: p.lo))
                if d < bestD { bestD = d; best = p }
            }
            guard let p = best else { continue }
            let region = CLCircularRegion(center: p.coordinate,
                                          radius: min(LocationManager.arrivalRadius, manager.maximumRegionMonitoringDistance),
                                          identifier: "site.\(site.id)")
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard alertsActive, region.identifier.hasPrefix("site."),
              let id = Int(region.identifier.dropFirst(5)),
              let site = DataStore.shared.site(id) else { return }
        arrive(site)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {}
}
