<p align="center"><img src="docs/design/appicon.png" width="120" alt="icon"></p>
<h1 align="center">Heritage Wander (世遗漫游)</h1>
<p align="center">[简体中文](README.md) · **English** · [日本語](README.ja.md) · [한국어](README.ko.md)</p>
<p align="center">A travel-destination app for iOS built on the UNESCO World Heritage List: a world heatmap, country maps, a destination wheel, on-device AI suggestions and trip planning.</p>
<p align="center">
<img src="https://img.shields.io/badge/platform-iOS%2016%2B-blue" alt="platform">
<img src="https://img.shields.io/badge/Swift-5-orange" alt="swift">
<img src="https://img.shields.io/badge/UI-SwiftUI-informational" alt="swiftui">
<img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-lightgrey" alt="license">
</p>

<table>
<tr><td align="center"><img src="docs/screenshots/explore.png" width="190" alt="World heatmap & timeline"><br><sub>World heatmap & timeline</sub></td><td align="center"><img src="docs/screenshots/wheel.png" width="190" alt="Destination wheel"><br><sub>Destination wheel</sub></td><td align="center"><img src="docs/screenshots/assistant.png" width="190" alt="AI destination picker"><br><sub>AI destination picker</sub></td><td align="center"><img src="docs/screenshots/footprint.png" width="190" alt="My footprint"><br><sub>My footprint</sub></td></tr>
<tr><td align="center"><img src="docs/screenshots/badges.png" width="190" alt="Badges"><br><sub>Badges</sub></td><td align="center"><img src="docs/screenshots/themes.png" width="190" alt="Colour themes"><br><sub>Colour themes</sub></td><td align="center"><img src="docs/screenshots/detail.png" width="190" alt="Site details & check-in"><br><sub>Site details & check-in</sub></td></tr>
</table>

## Overview

Heritage Wander puts all 1,273 sites on the UNESCO World Heritage List onto one zoomable world map. Start with the global heatmap, tap any country to see its sites, and open a site for its inscription year, criteria and a short history. When you can't decide where to go, spin the wheel or describe your trip in a sentence.

The app is written entirely in SwiftUI and MapKit with no third-party dependencies and no backend: the list data ships inside the app, and AI suggestions run on the device.

## Features

### Free

- **World heatmap**: a custom kernel-density heat layer that turns into clustered site pins as you zoom in. Switch between all, cultural, natural, mixed and endangered sites.
- **Country maps**: tap a country to see the sites inside it, with a card list.
- **Site details**: inscription year, category, criteria, description and a mini map, with links to Apple Maps and the official UNESCO page.
- **Destination wheel**: pick at random by region, category or your wish list, with 5–30 candidates.
- **Full list**: all 1,273 sites with search, filters and sorting.
- **Nearby sites**: sorted by straight-line distance from you.
- **Wish list and visits**: each visit can carry a date, a note and a photo.
- **Destination suggestions**: a set of sites that sit close together, chosen by days, category, region and distance.
- **Five languages**: Simplified Chinese, Traditional Chinese, English, Japanese and Korean. Site names and descriptions are localised too. The app follows the system language or your own choice.
- **Today's Site**: a daily notification and a Home Screen widget.

### Pro

- **AI travel assistant**: describe a trip in one sentence. On-device Apple Intelligence (Foundation Models) turns it into filters and writes the rationale. The model only interprets and explains; the sites themselves are always picked from the list by the app, so nothing is invented.
- **Trip planning**: string sites into a route, reorder by shortest path, estimate days and distance, export a calendar file or open the stops in Apple Maps.
- **Filtered wheels**: filter by distance, season and visited status, and save several wheels.
- **Arrival alerts and auto check-in**: get notified near a site and have it marked as visited.
- **Custom layers and timeline**: show only wish-list or unvisited sites, play the growth of the list since 1978, switch to satellite imagery.
- **Review and badges**: a year in review, region, category and milestone badges, and a shareable footprint poster.
- **Audio narration**, **offline photo packs**, **colour themes** (Celadon, Indigo, Sakura, Ink & Gold, Pine), a **footprint widget**, and an **unlimited wish list with iCloud sync**.

## Badge design

<p align="center"><img src="docs/design/badge_asia.svg" width="68" alt="asia"><img src="docs/design/badge_europe.svg" width="68" alt="europe"><img src="docs/design/badge_africa.svg" width="68" alt="africa"><img src="docs/design/badge_arab.svg" width="68" alt="arab"><img src="docs/design/badge_latin.svg" width="68" alt="latin"><img src="docs/design/badge_cultural.svg" width="68" alt="cultural"><img src="docs/design/badge_natural.svg" width="68" alt="natural"><img src="docs/design/badge_mixed.svg" width="68" alt="mixed"><img src="docs/design/badge_bronze.svg" width="68" alt="bronze"><img src="docs/design/badge_silver.svg" width="68" alt="silver"><img src="docs/design/badge_gold.svg" width="68" alt="gold"></p>

The badges and the app icon are vector originals in [`docs/design`](docs/design).

## Technical notes

| Area | Implementation |
|---|---|
| UI | SwiftUI, iOS 16 minimum |
| Maps | MapKit (`MKMapView` wrappers) with a custom `MKOverlayRenderer` that draws a Gaussian kernel-density heatmap per tile |
| Country hit-testing | Bundled Natural Earth 1:50m boundaries with point-in-polygon tests |
| AI | Foundation Models framework (iOS 26+) with structured output; falls back to manual filters when unavailable |
| Purchases | StoreKit 2, with a local StoreKit configuration file for testing |
| Widgets | WidgetKit, sharing a little state with the app through an App Group |
| Localisation | A small in-house string table, so the language switches at runtime without a restart |
| Data | The list ships inside the app and works offline |

## Build and run

1. You need Xcode 26 or later (the project is developed on Xcode 27).
2. Open `WorldHeritage.xcodeproj`, choose a simulator running iOS 16 or later, and run.
3. Debug builds have a "Debug: simulate Pro" switch under Me → Pro that unlocks every Pro feature.
4. The AI assistant needs iOS 26 or later on a device with Apple Intelligence turned on.
5. To run on a device, pick your own team under Signing & Capabilities and change the bundle ID and App Group to your own.

## Layout

```
WorldHeritage/            The app
  Models/                 Data model, localisation, favourites, location, themes
  Map/                    Heat layer and map wrappers
  Views/                  Explore, wheel, list and profile screens
  Features/               AI assistant, trip planning, review and badges
  Pro/                    Purchases and paywall
  Resources/              List and boundary data
HeritageWidget/           Home Screen widgets
docs/                     Screenshots and design originals
```

## Data sources

- The list, inscription years, criteria and descriptions come from public data of the [UNESCO World Heritage Centre](https://whc.unesco.org). Chinese text for entries without an official translation, and all Japanese and Korean text, was translated for this project and may contain mistakes. Corrections are welcome.
- Country boundaries come from [Natural Earth](https://www.naturalearthdata.com). They are used only for tap detection and do not imply any position.
- This project is not affiliated with or endorsed by UNESCO.

## License

The source code is released under the [PolyForm Noncommercial License 1.0.0](LICENSE.md). You are welcome to study it, modify it and use it for personal and other noncommercial purposes. **Commercial use is not permitted.** The author keeps the right to use it commercially, including publishing it on the App Store. Third-party data bundled with the app is not covered by this license; see [NOTICE](NOTICE).

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=DecHHts/WorldHeritage&type=Date)](https://star-history.com/#DecHHts/WorldHeritage&Date)
