import SwiftUI
import MapKit

enum PlanRoute: Hashable {
    case assistant
}

/// “规划”页：智能推荐入口 + 我的行程
struct PlanView: View {
    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var pro: ProStore

    @State private var path = NavigationPath()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: PlanRoute.assistant) {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    LinearGradient(colors: [Color(red: 0.45, green: 0.38, blue: 0.70),
                                                            Color(red: 0.25, green: 0.46, blue: 0.72)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(T("帮我选目的地"))
                                    .font(.headline)
                                Text(T("说出天数和喜好，得到一组顺路的世界遗产"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if trips.trips.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(T("还没有行程。点右上角新建，或从推荐结果里存为行程。"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                    } else {
                        ForEach(trips.trips) { trip in
                            NavigationLink(value: trip.id) {
                                TripRow(trip: trip)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    trips.delete(trip)
                                } label: {
                                    Label(T("删除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(T("我的行程"))
                        if !pro.isPro { ProBadge() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(T("规划"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if pro.isPro {
                            let t = trips.add(name: T("新行程"), sites: [])
                            path.append(t.id)
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(T("新建行程"))
                }
            }
            .navigationDestination(for: PlanRoute.self) { _ in
                AssistantView()
            }
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripID: id)
            }
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
            .paywall($showPaywall)
            .onAppear {
                guard path.isEmpty else { return }
                if DebugTour.on("assistant") || DebugTour.on("ai") { path.append(PlanRoute.assistant) }
                if DebugTour.on("trip") {
                    var c = TripCriteria()
                    c.countryISO = "JP"
                    let picked = Planner.recommend(c, origin: nil, wish: [], visited: [])
                    let t = trips.add(name: "Debug", sites: picked)
                    path.append(t.id)
                }
            }
        }
    }
}

struct TripRow: View {
    let trip: Trip

    var body: some View {
        let sites = trip.sites
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name.isEmpty ? T("新行程") : trip.name)
                .font(.body.weight(.medium))
            Text(T("%d 项 · 约 %d 天", sites.count, Planner.estimatedDays(sites)))
                .font(.caption)
                .foregroundColor(.secondary)
            if !sites.isEmpty {
                Text(sites.prefix(4).map { $0.name }.joined(separator: " → "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 行程详情

struct TripDetailView: View {
    let tripID: UUID

    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var favorites: FavoritesStore

    @State private var name = ""
    @State private var showPicker = false
    @State private var share: ShareItem? = nil
    @State private var loaded = false

    private var trip: Trip? { trips.trip(tripID) }

    var body: some View {
        Group {
            if let trip = trip {
                content(trip)
            } else {
                Text(T("这个行程已被删除"))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(T("行程"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let trip = trip {
                name = trip.name
                loaded = true
            }
        }
    }

    private func content(_ trip: Trip) -> some View {
        let sites = trip.sites
        let legs = Planner.legs(sites)
        let offsets = Planner.dayOffsets(sites)

        return List {
            if !sites.isEmpty {
                Section {
                    TripMapView(sites: sites)
                        .frame(height: 230)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                TextField(T("行程名称"), text: $name)
                    .onChange(of: name) { value in
                        var t = trip
                        t.name = value
                        trips.update(t)
                    }
                Toggle(T("设定出发日期"), isOn: Binding(
                    get: { trip.start != nil },
                    set: { on in
                        var t = trip
                        t.start = on ? Calendar.current.startOfDay(for: Date()) : nil
                        trips.update(t)
                    }))
                if let start = trip.start {
                    DatePicker(T("出发日期"), selection: Binding(
                        get: { start },
                        set: { d in
                            var t = trip
                            t.start = d
                            trips.update(t)
                        }), displayedComponents: .date)
                }
                LabeledContent(T("预计"), value: T("%d 项 · 约 %d 天 · 全程 %@",
                                                  sites.count, Planner.estimatedDays(sites),
                                                  Planner.kmText(legs.reduce(0, +))))
            } footer: {
                Text(T("天数按每项遗产一天、相邻两站超过 800 公里另加一天路程估算；距离为直线距离。"))
            }

            Section {
                if sites.isEmpty {
                    Text(T("还没有添加遗产"))
                        .foregroundColor(.secondary)
                }
                ForEach(Array(sites.enumerated()), id: \.element.id) { item in
                    NavigationLink(value: item.element) {
                        HStack(spacing: 12) {
                            Text("\(item.offset + 1)")
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(item.element.category.color)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.element.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(2)
                                Text(stopCaption(trip, index: item.offset, offsets: offsets, legs: legs,
                                                 site: item.element))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onMove { from, to in
                    var t = trip
                    t.siteIDs.move(fromOffsets: from, toOffset: to)
                    trips.update(t)
                }
                .onDelete { idx in
                    var t = trip
                    t.siteIDs.remove(atOffsets: idx)
                    trips.update(t)
                }

                Button {
                    showPicker = true
                } label: {
                    Label(T("添加遗产"), systemImage: "plus.circle.fill")
                }
                if sites.count > 2 {
                    Button {
                        var t = trip
                        t.siteIDs = Planner.order(sites, from: location.location?.coordinate).map { $0.id }
                        withAnimation { trips.update(t) }
                    } label: {
                        Label(T("按顺路重新排序"), systemImage: "arrow.triangle.swap")
                    }
                }
            } header: {
                Text(T("路线"))
            }

            if !sites.isEmpty {
                Section {
                    Button {
                        if let url = TripStore.icsFile(for: trip) {
                            share = ShareItem(items: [url])
                        }
                    } label: {
                        Label(T("导出到日历"), systemImage: "calendar.badge.plus")
                    }
                    Button {
                        openInMaps(sites)
                    } label: {
                        Label(T("在“地图”中打开全部地点"), systemImage: "map.fill")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showPicker) {
            SitePickerView(selected: Set(trip.siteIDs)) { ids in
                var t = trip
                // 保留原有顺序，新选的排在后面
                let kept = t.siteIDs.filter { ids.contains($0) }
                let added = ids.filter { !kept.contains($0) }
                t.siteIDs = kept + added
                trips.update(t)
            }
        }
        .sheet(item: $share) { item in
            ActivityView(items: item.items)
        }
    }

    private func stopCaption(_ trip: Trip, index: Int, offsets: [Int], legs: [Double], site: Site) -> String {
        var parts: [String] = []
        if let start = trip.start,
           let day = Calendar.current.date(byAdding: .day, value: offsets[index], to: start) {
            let f = DateFormatter()
            f.locale = L10n.lang.locale
            f.setLocalizedDateFormatFromTemplate("MMMd")
            parts.append(f.string(from: day))
        } else {
            parts.append(T("第 %d 天", offsets[index] + 1))
        }
        parts.append("\(site.flags) \(site.countryText)")
        if index > 0 { parts.append(T("距上一站 %@", Planner.kmText(legs[index - 1]))) }
        return parts.joined(separator: " · ")
    }

    private func openInMaps(_ sites: [Site]) {
        let items = sites.map { s -> MKMapItem in
            let item = MKMapItem(placemark: MKPlacemark(coordinate: s.coordinate))
            item.name = s.name
            return item
        }
        MKMapItem.openMaps(with: items, launchOptions: nil)
    }
}

/// 从名录里挑选遗产（“想去”的排在前面）
struct SitePickerView: View {
    @State var selected: Set<Int>
    let onDone: ([Int]) -> Void

    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    /// 记录点选顺序
    @State private var order: [Int] = []

    private var list: [Site] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = DataStore.shared.sites
        if q.isEmpty {
            let wish = favorites.wishSites
            let wishIDs = Set(wish.map { $0.id })
            let chosen = all.filter { selected.contains($0.id) && !wishIDs.contains($0.id) }
            return wish + chosen
        }
        return all.filter { s in
            s.n.lowercased().contains(q) || s.nt.lowercased().contains(q) || s.nj.lowercased().contains(q)
                || s.nk.lowercased().contains(q) || s.e.lowercased().contains(q)
                || s.countriesFull.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if list.isEmpty {
                    Text(search.isEmpty ? T("搜索遗产或国家名称；“想去”清单会显示在这里") : T("没有找到匹配的遗产"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                ForEach(list.prefix(200)) { site in
                    Button {
                        if selected.contains(site.id) {
                            selected.remove(site.id)
                            order.removeAll { $0 == site.id }
                        } else {
                            selected.insert(site.id)
                            order.append(site.id)
                        }
                    } label: {
                        HStack {
                            SiteRow(site: site)
                            Image(systemName: selected.contains(site.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected.contains(site.id) ? .accentColor : Color(.tertiaryLabel))
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: T("搜索遗产或国家"))
            .navigationTitle(T("已选 %d 项", selected.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("取消")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("完成")) {
                        let rest = selected.filter { !order.contains($0) }
                        onDone(Array(rest).sorted() + order)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 行程地图

final class StopAnnotation: NSObject, MKAnnotation {
    let site: Site
    let index: Int
    let coordinate: CLLocationCoordinate2D
    var title: String? { site.name }

    init(site: Site, index: Int) {
        self.site = site
        self.index = index
        self.coordinate = site.coordinate
    }
}

struct TripMapView: UIViewRepresentable {
    var sites: [Site]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = config
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "stop")
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let ids = sites.map { $0.id }
        if context.coordinator.ids == ids { return }
        context.coordinator.ids = ids
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)
        let stops = sites.enumerated().map { StopAnnotation(site: $0.element, index: $0.offset + 1) }
        map.addAnnotations(stops)
        if sites.count > 1 {
            var coords = sites.map { $0.coordinate }
            map.addOverlay(MKGeodesicPolyline(coordinates: &coords, count: coords.count))
        }
        if sites.count == 1 {
            map.setRegion(MKCoordinateRegion(center: sites[0].coordinate,
                                             span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)),
                          animated: false)
        } else if !stops.isEmpty {
            var rect = MKMapRect.null
            for s in stops {
                let p = MKMapPoint(s.coordinate)
                rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
            }
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 36, bottom: 30, right: 36),
                                  animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var ids: [Int] = []

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stop = annotation as? StopAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "stop", for: annotation)
            if let marker = v as? MKMarkerAnnotationView {
                marker.glyphText = "\(stop.index)"
                marker.glyphImage = nil
                marker.markerTintColor = stop.site.category.uiColor
                marker.displayPriority = .required
                marker.titleVisibility = .adaptive
            }
            return v
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = UIColor(Theme.current.accent).withAlphaComponent(0.9)
                r.lineWidth = 3
                r.lineDashPattern = [6, 5]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
