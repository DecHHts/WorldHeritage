import SwiftUI

@main
struct WorldHeritageApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var location = LocationManager()
    @StateObject private var pro = ProStore()
    @StateObject private var trips = TripStore()
    @StateObject private var narrator = Narrator()
    @StateObject private var journal = JournalStore.shared
    @StateObject private var offline = OfflineStore.shared
    @StateObject private var deepLink = DeepLink.shared

    init() {
        Notifier.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(favorites)
                .environmentObject(location)
                .environmentObject(pro)
                .environmentObject(trips)
                .environmentObject(narrator)
                .environmentObject(journal)
                .environmentObject(offline)
                .environmentObject(deepLink)
                .onOpenURL { url in deepLink.handle(url) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var deepLink: DeepLink
    @State private var tab = DebugTour.tab
    @State private var tourPaywall = false
    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        TabView(selection: $tab) {
            ExploreView()
                .tabItem { Label(T("探索"), systemImage: "globe.asia.australia.fill") }
                .tag(0)
            WheelView()
                .tabItem { Label(T("转盘"), systemImage: "dial.medium.fill") }
                .tag(1)
            PlanView()
                .tabItem { Label(T("规划"), systemImage: "sparkles") }
                .tag(4)
            CatalogView()
                .tabItem { Label(T("名录"), systemImage: "list.bullet.rectangle.portrait.fill") }
                .tag(2)
            MineView()
                .tabItem { Label(T("我的"), systemImage: "heart.fill") }
                .tag(3)
        }
        .paywall($tourPaywall)
        .onAppear {
            if DebugTour.on("paywall") { tourPaywall = true }
            if DebugTour.active, DebugTour.scene.hasPrefix("theme:") { settings.themeID = String(DebugTour.scene.dropFirst(6)) }
            if DebugTour.on("reset") {
                // 清掉自测时留下的数据
                for t in trips.trips where t.name == "Debug" { trips.delete(t) }
                if let s = DataStore.shared.site(1), favorites.isVisited(s) { favorites.toggleVisited(s) }
            }
            if DebugTour.on("detail"), let s = DataStore.shared.site(1) {
                favorites.markVisited(s)
                deepLink.open(id: 1)
            }
        }
        // 从通知或小组件打开某项遗产
        .sheet(item: $deepLink.site) { site in
            NavigationStack {
                SiteDetailView(site: site, showsClose: true)
            }
        }
        // 切换语言时整体重建界面
        .id(settings.lang)
        .environment(\.locale, settings.lang.locale)
        .tint(settings.theme.accent)
        .accentColor(settings.theme.accent)
        .preferredColorScheme(settings.theme.scheme)
    }
}
