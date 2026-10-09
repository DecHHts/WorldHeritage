import SwiftUI

struct RemoteImage: View {
    let url: URL?
    var symbol: String = "photo"

    var body: some View {
        if let url = url, let local = OfflineStore.localImage(for: url) {
            Image(uiImage: local).resizable().scaledToFill()
        } else if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                case .empty:
                    ZStack {
                        placeholder
                        ProgressView()
                    }
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: symbol)
                .font(.title)
                .foregroundColor(Color(.tertiaryLabel))
        }
    }
}

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol = symbol {
                Image(systemName: symbol).font(.caption2)
            }
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundColor(color)
        .background(color.opacity(0.13))
        .clipShape(Capsule())
    }
}

struct CategoryIcon: View {
    let category: HeritageCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(category.color)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// 列表行
struct SiteRow: View {
    let site: Site
    /// 用缩略图代替类别图标
    var thumbnail: Bool = false
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        HStack(spacing: 12) {
            if thumbnail {
                RemoteImage(url: site.imageURL, symbol: site.category.symbol)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                CategoryIcon(category: site.category)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(site.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text("\(site.flags) \(site.countryText) · \(site.yearText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !thumbnail {
                if favorites.isVisited(site) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.footnote)
                } else if favorites.isWish(site) {
                    Image(systemName: "heart.fill").foregroundColor(.pink).font(.footnote)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 国家页底部的横向卡片
struct SiteCard: View {
    let site: Site

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: site.imageURL, symbol: site.category.symbol)
                .frame(width: 190, height: 96)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Image(systemName: site.category.symbol)
                        .foregroundColor(site.category.color)
                    Text("\(site.category.shortTitle) · \(site.yearText)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .padding(10)
            .frame(width: 190, height: 74, alignment: .topLeading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }
}
