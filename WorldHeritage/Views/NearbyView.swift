import SwiftUI
import CoreLocation
import UIKit

/// 附近的世界遗产：按直线距离由近到远
struct NearbyView: View {
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var settings: AppSettings

    private struct Entry: Identifiable {
        let site: Site
        let meters: Double
        var id: Int { site.id }
    }

    private let limit = 60

    private func entries(from here: CLLocation) -> [Entry] {
        var list: [Entry] = []
        for s in DataStore.shared.sites(layer: settings.layer) {
            var best = Double.greatestFiniteMagnitude
            for p in s.p {
                let d = here.distance(from: CLLocation(latitude: p.la, longitude: p.lo))
                if d < best { best = d }
            }
            list.append(Entry(site: s, meters: best))
        }
        list.sort { $0.meters < $1.meters }
        return Array(list.prefix(limit))
    }

    var body: some View {
        Group {
            if let here = location.location {
                List {
                    Section {
                        ForEach(entries(from: here)) { entry in
                            NavigationLink(value: entry.site) {
                                HStack(spacing: 8) {
                                    SiteRow(site: entry.site)
                                    Text(NearbyView.format(entry.meters))
                                        .font(.footnote.weight(.semibold).monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(T("%@ · 由近到远 · 直线距离", settings.layer.title))
                    }
                }
                .listStyle(.plain)
            } else if location.isDenied {
                message(symbol: "location.slash",
                        text: T("请在“设置 > 隐私与安全性 > 定位服务”中允许本 App 使用位置。"),
                        button: T("打开设置")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else if location.status == .notDetermined {
                message(symbol: "location.circle",
                        text: T("需要你的位置来计算距离，位置只在本机使用，不会上传。"),
                        button: T("允许使用位置")) {
                    location.request()
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(T("正在定位…")).font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(T("附近"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { location.request() }
    }

    private func message(symbol: String, text: String, button: String,
                         action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func format(_ meters: Double) -> String {
        if meters < 1000 { return T("%d 米", Int(meters)) }
        let km = meters / 1000
        if km < 100 { return T("%@ 公里", String(format: "%.1f", km)) }
        return T("%@ 公里", String(Int(km.rounded())))
    }
}
