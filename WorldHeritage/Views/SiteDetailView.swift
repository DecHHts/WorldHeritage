import SwiftUI
import MapKit
import PhotosUI

struct SiteDetailView: View {
    let site: Site
    var showsClose: Bool = false

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var journal: JournalStore
    @EnvironmentObject private var narrator: Narrator
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var limitHint = false
    @State private var note = ""
    @State private var pickedPhoto: PhotosPickerItem? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if site.imageURL != nil {
                    RemoteImage(url: site.imageURL, symbol: site.category.symbol)
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    actionButtons
                    if favorites.isVisited(site) { journalSection }
                    section(T("遗产简介"), symbol: "text.book.closed.fill", accessory: AnyView(narrateButton)) {
                        Text(site.summary)
                            .font(.body)
                            .lineSpacing(5)
                        if site.t && (L10n.lang == .hans || L10n.lang == .hant) {
                            Text(T("官方暂未提供中文介绍，以上内容根据联合国教科文组织英文简介编译。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if !site.cr.isEmpty {
                        section(T("入选标准"), symbol: "checkmark.seal.fill") {
                            ForEach(site.cr, id: \.self) { c in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("(\(c))")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(site.category.color)
                                        .frame(width: 40, alignment: .leading)
                                    Text(Criteria.localized(c))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(3)
                                }
                            }
                        }
                    }
                    section(T("位置"), symbol: "map.fill") {
                        MiniMapView(site: site)
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("\(site.flags) \(site.countriesFull)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button {
                            openInMaps()
                        } label: {
                            Label(T("在“地图”中打开"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if let url = site.officialURL {
                        Link(destination: url) {
                            HStack {
                                Label(T("联合国教科文组织官方页面"), systemImage: "safari.fill")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    Text(T("资料来源：UNESCO World Heritage Centre（whc.unesco.org）"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(site.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { note = journal.entry(site.id)?.note ?? "" }
        .onDisappear { if narrator.speakingID == site.id { narrator.stop() } }
        .paywall($showPaywall)
        .alert(T("免费版最多收藏 %d 项", Pro.freeWishLimit), isPresented: $limitHint) {
            Button(T("了解订阅")) { showPaywall = true }
            Button(T("好"), role: .cancel) {}
        } message: {
            Text(T("订阅后“想去”清单不限数量，并可通过 iCloud 在设备间同步。"))
        }
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("完成")) { dismiss() }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(site.name)
                .font(.title2.weight(.bold))
            if let alt = site.altName {
                Text(alt)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            FlowChips(site: site)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if !favorites.toggleWish(site) { limitHint = true }
            } label: {
                Label(favorites.isWish(site) ? T("已想去") : T("想去"),
                      systemImage: favorites.isWish(site) ? "heart.fill" : "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.pink)

            Button {
                favorites.toggleVisited(site)
                note = journal.entry(site.id)?.note ?? ""
            } label: {
                Label(favorites.isVisited(site) ? T("已去过") : T("去过"),
                      systemImage: favorites.isVisited(site) ? "checkmark.seal.fill" : "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
    }

    /// 语音讲解（订阅功能）
    private var narrateButton: some View {
        Button {
            if pro.isPro {
                narrator.toggle(site)
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: narrator.speakingID == site.id ? "stop.fill" : "speaker.wave.2.fill")
                Text(narrator.speakingID == site.id ? T("停止") : T("朗读"))
                if !pro.isPro { ProBadge() }
            }
            .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// 我的打卡：日期、照片、一句话
    private var journalSection: some View {
        section(T("我的打卡"), symbol: "checkmark.seal.fill") {
            DatePicker(T("到访日期"),
                       selection: Binding(
                        get: { journal.entry(site.id)?.date ?? Date() },
                        set: { journal.setDate(site.id, $0) }),
                       in: ...Date(), displayedComponents: .date)
            TextField(T("写一句话记下这次到访"), text: $note, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .onChange(of: note) { value in
                    journal.setNote(site.id, value)
                }
            if let photo = journal.photo(site.id) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .id(journal.photoVersion)
            }
            HStack {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label(journal.photo(site.id) == nil ? T("添加照片") : T("更换照片"), systemImage: "photo")
                }
                .buttonStyle(.bordered)
                if journal.photo(site.id) != nil {
                    Button(role: .destructive) {
                        journal.removePhoto(site.id)
                    } label: {
                        Label(T("移除照片"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.footnote)
            .onChange(of: pickedPhoto) { item in
                guard let item = item else { return }
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        journal.setPhoto(site.id, data: data)
                    }
                    pickedPhoto = nil
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, symbol: String, accessory: AnyView? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline)
                Spacer()
                if let accessory = accessory { accessory }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: site.coordinate))
        item.name = site.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: site.coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        ])
    }
}

/// 详情页标题下的一排标签
struct FlowChips: View {
    let site: Site

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: T("%@ 年列入", String(site.y)), symbol: "calendar", color: .blue)
                Chip(text: site.category.title, symbol: site.category.symbol, color: site.category.color)
                if site.tn {
                    Chip(text: T("跨国遗产"), symbol: "globe", color: .indigo)
                }
                if site.dg {
                    Chip(text: T("濒危"), symbol: "exclamationmark.triangle.fill", color: .red)
                }
                ForEach(site.r, id: \.self) { r in
                    Chip(text: T(r), color: .secondary)
                }
            }
        }
    }
}
