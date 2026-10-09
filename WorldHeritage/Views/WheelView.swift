import SwiftUI
import UIKit

/// 目的地转盘：给选择困难症一点随机性
struct WheelView: View {
    @EnvironmentObject private var favorites: FavoritesStore

    @State private var candidates: [Site] = []
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: Site? = nil
    @State private var region: String? = nil
    @State private var category: HeritageCategory? = nil
    @State private var onlyWish = false
    // 订阅条件
    @State private var maxKm: Double? = nil
    @State private var seasonal = false
    @State private var unvisited = false
    @State private var showPaywall = false
    @State private var limitHint = false
    @State private var naming = false
    @State private var presetName = ""
    @AppStorage("wheel.presets") private var presetsJSON = "[]"

    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var location: LocationManager

    /// 转盘上的候选数量，可在 5–30 之间调整
    @AppStorage("wheel.slots") private var slots = 8
    private let store = DataStore.shared

    private var presets: [WheelPreset] {
        (try? JSONDecoder().decode([WheelPreset].self, from: Data(presetsJSON.utf8))) ?? []
    }

    private func storePresets(_ list: [WheelPreset]) {
        if let data = try? JSONEncoder().encode(list), let text = String(data: data, encoding: .utf8) {
            presetsJSON = text
        }
    }

    private var pool: [Site] {
        let month = Calendar.current.component(.month, from: Date())
        let here = location.location?.coordinate
        return store.sites.filter { s in
            if let region = region, !s.r.contains(region) { return false }
            if let category = category, s.category != category { return false }
            if onlyWish && !favorites.isWish(s) { return false }
            if pro.isPro {
                if unvisited && favorites.isVisited(s) { return false }
                if seasonal && !Planner.inSeason(s, month: month) { return false }
                if let maxKm = maxKm, let here = here, Planner.km(s, from: here) > maxKm { return false }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    filters
                    proFilters
                    slotStepper

                    if candidates.count < 2 {
                        emptyState
                    } else {
                        wheel
                        controls
                    }

                    if let result = result {
                        resultCard(result)
                            .id("result")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(T("目的地转盘"))
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
            .onAppear {
                if candidates.isEmpty { refill() }
            }
            .onChange(of: region) { _ in refill() }
            .onChange(of: category) { _ in refill() }
            .onChange(of: onlyWish) { _ in refill() }
            .onChange(of: slots) { _ in refill() }
            .onChange(of: maxKm) { _ in refill() }
            .onChange(of: seasonal) { _ in refill() }
            .onChange(of: unvisited) { _ in refill() }
            .paywall($showPaywall)
            .alert(T("保存这个转盘"), isPresented: $naming) {
                TextField(T("名称"), text: $presetName)
                Button(T("保存")) { savePreset() }
                Button(T("取消"), role: .cancel) {}
            }
            .alert(T("免费版最多收藏 %d 项", Pro.freeWishLimit), isPresented: $limitHint) {
                Button(T("了解订阅")) { showPaywall = true }
                Button(T("好"), role: .cancel) {}
            }
            .onChange(of: result) { value in
                guard value != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("result", anchor: .bottom)
                    }
                }
            }
            }
        }
    }

    // MARK: 筛选

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker(T("地区"), selection: $region) {
                        Label(T("全球"), systemImage: "globe").tag(String?.none)
                        ForEach(store.regions, id: \.self) { r in
                            Text(T(r)).tag(String?.some(r))
                        }
                    }
                } label: {
                    filterLabel(region.map { T($0) } ?? T("全球"), symbol: "globe")
                }

                Menu {
                    Picker(T("类别"), selection: $category) {
                        Label(T("全部类别"), systemImage: "square.grid.2x2").tag(HeritageCategory?.none)
                        ForEach(HeritageCategory.allCases) { c in
                            Label(c.title, systemImage: c.symbol).tag(HeritageCategory?.some(c))
                        }
                    }
                } label: {
                    filterLabel(category?.title ?? T("全部类别"), symbol: "square.grid.2x2")
                }

                Button {
                    onlyWish.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: onlyWish ? "heart.fill" : "heart")
                        Text(T("只转想去的"))
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundColor(onlyWish ? .white : .primary)
                    .background(onlyWish ? Color.pink : Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
        }
        .disabled(spinning)
    }

    // MARK: 订阅条件

    private func proChip(_ text: String, symbol: String, on: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundColor(on ? .white : .primary)
        .background(on ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    private var proFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !pro.isPro { ProBadge() }

                Menu {
                    Picker(T("距离"), selection: Binding(
                        get: { maxKm },
                        set: { v in if pro.isPro { maxKm = v } else { showPaywall = true } })) {
                        Text(T("不限")).tag(Double?.none)
                        ForEach(Planner.distanceOptions, id: \.self) { km in
                            Text(T("%@ 以内", Planner.kmText(km))).tag(Double?.some(km))
                        }
                    }
                } label: {
                    proChip(maxKm.map { T("%@ 以内", Planner.kmText($0)) } ?? T("距离不限"),
                            symbol: "location.circle", on: maxKm != nil)
                }

                Button {
                    if pro.isPro { seasonal.toggle() } else { showPaywall = true }
                } label: {
                    proChip(T("避开当地冬季"), symbol: "sun.max", on: seasonal)
                }

                Button {
                    if pro.isPro { unvisited.toggle() } else { showPaywall = true }
                } label: {
                    proChip(T("不含去过的"), symbol: "checkmark.seal", on: unvisited)
                }

                Menu {
                    Button {
                        if pro.isPro {
                            presetName = ""
                            naming = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label(T("保存当前条件…"), systemImage: "plus")
                    }
                    if !presets.isEmpty {
                        Section(T("已保存的转盘")) {
                            ForEach(presets) { p in
                                Button(p.name) { apply(p) }
                            }
                        }
                        Section {
                            ForEach(presets) { p in
                                Button(role: .destructive) {
                                    storePresets(presets.filter { $0.id != p.id })
                                } label: {
                                    Label(T("删除“%@”", p.name), systemImage: "trash")
                                }
                            }
                        }
                    }
                } label: {
                    proChip(T("我的转盘"), symbol: "tray.full", on: false)
                }
            }
        }
        .disabled(spinning)
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        var list = presets
        list.append(WheelPreset(name: name.isEmpty ? T("转盘 %d", list.count + 1) : name,
                                region: region, category: category?.rawValue, onlyWish: onlyWish,
                                maxKm: maxKm, seasonal: seasonal, unvisited: unvisited, slots: slots))
        storePresets(list)
    }

    private func apply(_ p: WheelPreset) {
        guard pro.isPro else {
            showPaywall = true
            return
        }
        region = p.region
        category = p.category.flatMap { HeritageCategory(rawValue: $0) }
        onlyWish = p.onlyWish
        maxKm = p.maxKm
        seasonal = p.seasonal
        unvisited = p.unvisited
        slots = min(max(p.slots, 5), 30)
        refill()
    }

    private var slotStepper: some View {
        Stepper(value: $slots, in: 5...30) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill").foregroundColor(.secondary)
                Text(T("候选数量"))
                Text("\(slots)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundColor(.accentColor)
                if candidates.count < slots && candidates.count >= 2 {
                    Text(T("（符合条件的只有 %d 项）", candidates.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(spinning)
    }

    private func filterLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundColor(.primary)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    // MARK: 转盘

    private var wheel: some View {
        ZStack(alignment: .top) {
            WheelDisc(sites: candidates, theme: settings.theme)
                .rotationEffect(.degrees(rotation))
                .padding(.top, 16)
                .onTapGesture { spin() }

            WheelPointer(color: settings.theme.accent)
        }
        .frame(maxWidth: 360)
        .aspectRatio(1, contentMode: .fit)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                refill()
            } label: {
                Label(T("换一批"), systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                spin()
            } label: {
                Label(spinning ? T("转动中…") : T("开始转动"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .disabled(spinning)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dial.low")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(onlyWish ? T("“想去”清单里至少要有 2 项遗产才能转") : T("符合条件的遗产不足 2 项"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private func resultCard(_ site: Site) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: site.imageURL, symbol: site.category.symbol)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text(T("就去这里吧"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(site.name)
                    .font(.title3.weight(.bold))
                Text("\(site.flags) \(site.countryText) · \(T("%@ 年列入", String(site.y))) · \(site.category.title)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(site.summary)
                    .font(.subheadline)
                    .lineLimit(3)
                    .lineSpacing(3)
                HStack(spacing: 12) {
                    NavigationLink(value: site) {
                        Label(T("查看详情"), systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        if !favorites.toggleWish(site) { limitHint = true }
                    } label: {
                        Label(favorites.isWish(site) ? T("已想去") : T("想去"),
                              systemImage: favorites.isWish(site) ? "heart.fill" : "heart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.pink)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: 逻辑

    private func refill() {
        guard !spinning else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            candidates = Array(pool.shuffled().prefix(min(max(slots, 5), 30)))
            result = nil
        }
    }

    private func spin() {
        let n = candidates.count
        guard !spinning, n >= 2 else { return }
        spinning = true
        withAnimation(.easeInOut(duration: 0.2)) { result = nil }

        let index = Int.random(in: 0..<n)
        let theta = 360.0 / Double(n)
        // 让第 index 个扇区的中线停在正上方的指针处，并加一点扇区内的随机偏移
        let jitter = Double.random(in: -0.35...0.35) * theta
        let target = -(Double(index) + 0.5) * theta + jitter
        var delta = (target - rotation).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let duration = 4.6

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.timingCurve(0.12, 0.82, 0.22, 1.0, duration: duration)) {
            rotation += 360.0 * 6 + delta
        }
        let picked = candidates[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            spinning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                result = picked
            }
        }
    }
}

/// 保存下来的一组转盘条件
struct WheelPreset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var region: String?
    var category: String?
    var onlyWish: Bool
    var maxKm: Double?
    var seasonal: Bool
    var unvisited: Bool
    var slots: Int
}

// MARK: - 转盘盘面

struct SectorShape: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                 startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct WheelDisc: View {
    let sites: [Site]
    var theme: Theme = .current
    /// 没有候选时画几格空扇区（主题预览用）
    var placeholderSlots: Int = 0

    private func tone(_ i: Int, _ n: Int) -> Color {
        let k = theme.wheel.count
        // 最后一格避免和第一格同色
        if i == n - 1 && i % k == 0 && n > 1 { return theme.wheel[1 % k] }
        return theme.wheel[i % k]
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            let n = max(sites.isEmpty ? placeholderSlots : sites.count, 1)
            let theta = 360.0 / Double(n)
            // 外圈留给轮缘，扇区画在里面
            let inner = r * 0.9
            // 标签所在半径处的弦长决定可用高度：扇区越多字越小、行数越少
            let chord = max(9, 2 * inner * 0.6 * CGFloat(sin(theta / 2 * .pi / 180)) * 0.86)
            let lines = n <= 12 ? 2 : 1
            let fontSize = min(inner * 0.085, chord / CGFloat(lines) * 0.78)

            ZStack {
                // 轮缘
                Circle().fill(theme.rim)
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    .padding(1)

                // 扇区
                ZStack {
                    ForEach(0..<n, id: \.self) { i in
                        SectorShape(start: .degrees(-90 + theta * Double(i)),
                                    end: .degrees(-90 + theta * Double(i + 1)))
                            .fill(tone(i, n))
                    }
                    ForEach(0..<n, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: inner, height: n > 16 ? 0.6 : 1)
                            .offset(x: inner / 2)
                            .rotationEffect(.degrees(-90 + theta * Double(i)))
                    }
                    ForEach(Array(sites.enumerated()), id: \.element.id) { item in
                        Text(item.element.name)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(lines)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
                            .frame(width: inner * 0.60, height: chord)
                            .offset(x: inner * 0.62)
                            .rotationEffect(.degrees(-90 + theta * (Double(item.offset) + 0.5)))
                    }
                    // 由中心向外略微压暗，做出一点厚度
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.20)],
                                             center: .center, startRadius: inner * 0.12, endRadius: inner))
                        .allowsHitTesting(false)
                }
                .frame(width: inner * 2, height: inner * 2)
                .clipShape(Circle())

                // 轮缘上的小钉
                ForEach(0..<n, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: max(2, r * 0.03), height: max(2, r * 0.03))
                        .offset(x: r * 0.95)
                        .rotationEffect(.degrees(-90 + theta * Double(i)))
                }

                // 轮毂
                Circle()
                    .fill(theme.rim)
                    .frame(width: r * 0.34, height: r * 0.34)
                    .shadow(color: .black.opacity(0.3), radius: r * 0.03, y: r * 0.01)
                Circle()
                    .fill(LinearGradient(colors: [Color.white, Color(white: 0.86)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: r * 0.27, height: r * 0.27)
                Image(systemName: "airplane")
                    .font(.system(size: r * 0.12, weight: .bold))
                    .foregroundColor(theme.rim)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(0.22), radius: r * 0.06, y: r * 0.03)
        }
    }
}

/// 转盘顶部的指针
struct WheelPointer: View {
    var color: Color

    private struct Drop: Shape {
        func path(in rect: CGRect) -> Path {
            let rad = rect.width / 2
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rad),
                           control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62))
            p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + rad), radius: rad,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                           control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62))
            p.closeSubpath()
            return p
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Drop()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .padding(.top, 7)
        }
        .frame(width: 28, height: 40)
    }
}
