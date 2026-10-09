import SwiftUI
import MapKit

private func makeBaseMap() -> MKMapView {
    let map = MKMapView(frame: .zero)
    let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
    config.pointOfInterestFilter = .excludingAll
    map.preferredConfiguration = config
    map.isRotateEnabled = false
    map.isPitchEnabled = false
    map.showsCompass = false
    return map
}

private func multiPolygon(for country: Country) -> MKMultiPolygon {
    let polys = country.polygons.map { poly -> MKPolygon in
        var ring = poly.ring
        return MKPolygon(coordinates: &ring, count: ring.count)
    }
    return MKMultiPolygon(polys)
}

// MARK: - 一级：世界热力图（放大后显示遗产图钉）

struct WorldMapView: UIViewRepresentable {
    /// 改变该值会让地图回到世界视图
    var resetToken: Int
    /// 改变该值会让地图移动到用户当前位置
    var locateToken: Int
    var userCoordinate: CLLocationCoordinate2D?
    var layer: HeatLayer
    /// 图层内容变化（收藏变动、时间轴年份）时改变该值以重建
    var version: Int = 0
    var satellite: Bool = false
    var onTapCountry: (Country) -> Void
    var onSelectSite: (Site) -> Void

    static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30, longitude: 70),
        span: MKCoordinateSpan(latitudeDelta: 110, longitudeDelta: 110))

    /// 经度跨度小于该值时，从热力图切换为图钉
    static let pinSpanThreshold = 16.0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = makeBaseMap()
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "site")
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.showsUserLocation = true
        map.tintColor = .systemBlue
        context.coordinator.layer = layer
        context.coordinator.version = version
        map.addOverlay(HeatOverlay(points: DataStore.shared.heatPoints(layer: layer)), level: .aboveRoads)
        map.setRegion(WorldMapView.worldRegion, animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        context.coordinator.lastReset = resetToken
        context.coordinator.lastLocate = locateToken
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.layer != layer || c.version != version {
            c.version = version
            c.switchLayer(layer, on: map)
        }
        if c.satellite != satellite {
            c.satellite = satellite
            if satellite {
                map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat)
            } else {
                let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                config.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = config
            }
        }
        if c.lastReset != resetToken {
            c.lastReset = resetToken
            map.setRegion(WorldMapView.worldRegion, animated: true)
        }
        if c.lastLocate != locateToken {
            c.lastLocate = locateToken
            if let coord = userCoordinate ?? map.userLocation.location?.coordinate {
                map.setRegion(MKCoordinateRegion(center: coord,
                                                 span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)),
                              animated: true)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: WorldMapView
        var lastReset = 0
        var lastLocate = 0
        private var highlight: MKMultiPolygon?
        private var pinsShown = false
        private weak var heatRenderer: HeatRenderer?
        var layer: HeatLayer = .all
        var version = 0
        var satellite = false
        private var pinsLayer: HeatLayer?
        private var pins: [SiteAnnotation] = []

        private func buildPinsIfNeeded() {
            if pinsLayer == layer { return }
            pinsLayer = layer
            var list: [SiteAnnotation] = []
            for s in DataStore.shared.sites(layer: layer) {
                for p in s.p { list.append(SiteAnnotation(site: s, coordinate: p.coordinate)) }
            }
            pins = list
        }

        /// 切换名录：重建热力图和图钉
        func switchLayer(_ newLayer: HeatLayer, on map: MKMapView) {
            if pinsShown { map.removeAnnotations(pins) }
            for overlay in map.overlays where overlay is HeatOverlay { map.removeOverlay(overlay) }
            pinsLayer = nil
            layer = newLayer
            map.addOverlay(HeatOverlay(points: DataStore.shared.heatPoints(layer: newLayer)), level: .aboveRoads)
            if pinsShown {
                buildPinsIfNeeded()
                map.addAnnotations(pins)
            }
        }

        init(_ parent: WorldMapView) { self.parent = parent }

        // 缩放到一定程度后：热力图淡出，显示具体遗产的图钉
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let zoomedIn = mapView.region.span.longitudeDelta < WorldMapView.pinSpanThreshold
            if zoomedIn == pinsShown { return }
            pinsShown = zoomedIn
            if zoomedIn {
                buildPinsIfNeeded()
                mapView.addAnnotations(pins)
            } else {
                mapView.removeAnnotations(pins)
            }
            heatRenderer?.alpha = zoomedIn ? 0.3 : 1.0
            heatRenderer?.setNeedsDisplay()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            // 点在图钉上时交给图钉处理，不进入国家
            var hit: UIView? = map.hitTest(point, with: nil)
            while let view = hit {
                if view is MKAnnotationView { return }
                hit = view.superview
            }
            let coord = map.convert(point, toCoordinateFrom: map)
            guard let country = DataStore.shared.country(at: coord) else { return }

            if let old = highlight { map.removeOverlay(old) }
            let overlay = multiPolygon(for: country)
            highlight = overlay
            map.addOverlay(overlay, level: .aboveLabels)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak map] in
                guard let self = self, let map = map, self.highlight === overlay else { return }
                map.removeOverlay(overlay)
                self.highlight = nil
            }
            parent.onTapCountry(country)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        // 双击缩放优先，避免双击时误进国家
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
            if let tap = other as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 { return true }
            return false
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            return siteAnnotationView(mapView, annotation)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let item = view.annotation as? SiteAnnotation {
                mapView.deselectAnnotation(item, animated: false)
                parent.onSelectSite(item.site)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let heat = overlay as? HeatOverlay {
                let r = HeatRenderer(heat: heat)
                r.alpha = pinsShown ? 0.3 : 1.0
                heatRenderer = r
                return r
            }
            if let multi = overlay as? MKMultiPolygon {
                let r = MKMultiPolygonRenderer(multiPolygon: multi)
                r.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                r.strokeColor = UIColor.systemOrange
                r.lineWidth = 1.5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

/// 遗产图钉 / 聚合图钉的统一外观
private func siteAnnotationView(_ mapView: MKMapView, _ annotation: MKAnnotation) -> MKAnnotationView? {
    if let cluster = annotation as? MKClusterAnnotation {
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster)
        if let marker = view as? MKMarkerAnnotationView {
            marker.markerTintColor = UIColor.darkGray
            marker.glyphImage = nil
            marker.glyphText = "\(cluster.memberAnnotations.count)"
            marker.titleVisibility = .hidden
            marker.subtitleVisibility = .hidden
            marker.canShowCallout = false
        }
        return view
    }
    guard let item = annotation as? SiteAnnotation else { return nil }
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: "site", for: item)
    if let marker = view as? MKMarkerAnnotationView {
        marker.clusteringIdentifier = "site"
        marker.markerTintColor = item.site.category.uiColor
        marker.glyphText = nil
        marker.glyphImage = UIImage(systemName: item.site.category.symbol)
        marker.titleVisibility = .adaptive
        marker.subtitleVisibility = .hidden
        marker.canShowCallout = false
        marker.displayPriority = .defaultHigh
    }
    return view
}

// MARK: - 二级：国家地图

final class SiteAnnotation: NSObject, MKAnnotation {
    let site: Site
    let coordinate: CLLocationCoordinate2D
    var title: String? { site.name }

    init(site: Site, coordinate: CLLocationCoordinate2D) {
        self.site = site
        self.coordinate = coordinate
        super.init()
    }
}

struct CountryMapView: UIViewRepresentable {
    let country: Country
    var sites: [Site]
    var onSelect: (Site) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = makeBaseMap()
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "site")
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.addOverlay(multiPolygon(for: country), level: .aboveRoads)
        map.setRegion(map.regionThatFits(country.region), animated: false)
        context.coordinator.apply(sites: sites, to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(sites: sites, to: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountryMapView
        private var shownIDs: [Int] = []

        init(_ parent: CountryMapView) { self.parent = parent }

        func apply(sites: [Site], to map: MKMapView) {
            let ids = sites.map { $0.id }
            if ids == shownIDs { return }
            shownIDs = ids
            map.removeAnnotations(map.annotations)
            let iso = parent.country.iso
            map.addAnnotations(sites.map { SiteAnnotation(site: $0, coordinate: $0.coordinate(in: iso)) })
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            siteAnnotationView(mapView, annotation)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let item = view.annotation as? SiteAnnotation {
                mapView.deselectAnnotation(item, animated: false)
                parent.onSelect(item.site)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let multi = overlay as? MKMultiPolygon {
                let r = MKMultiPolygonRenderer(multiPolygon: multi)
                r.fillColor = UIColor.systemOrange.withAlphaComponent(0.07)
                r.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
                r.lineWidth = 1.2
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - 详情页小地图

struct MiniMapView: UIViewRepresentable {
    let site: Site

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = makeBaseMap()
        map.delegate = context.coordinator
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        let annotations = site.p.map { SiteAnnotation(site: site, coordinate: $0.coordinate) }
        map.addAnnotations(annotations)
        if annotations.count == 1 {
            map.setRegion(MKCoordinateRegion(center: site.coordinate,
                                             span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)),
                          animated: false)
        } else {
            map.showAnnotations(annotations, animated: false)
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let item = annotation as? SiteAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: item, reuseIdentifier: nil)
            view.markerTintColor = item.site.category.uiColor
            view.glyphImage = UIImage(systemName: item.site.category.symbol)
            view.titleVisibility = .hidden
            return view
        }
    }
}

