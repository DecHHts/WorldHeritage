<p align="center"><img src="docs/design/appicon.png" width="120" alt="icon"></p>
<h1 align="center">세계유산 산책 (世遗漫游)</h1>
<p align="center">[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · **한국어**</p>
<p align="center">유네스코 세계유산 목록을 바탕으로 만든 여행지 추천 iOS 앱입니다. 세계 히트맵, 국가별 지도, 목적지 룰렛, 기기에서 동작하는 AI 추천, 여행 일정 계획을 제공합니다.</p>
<p align="center">
<img src="https://img.shields.io/badge/platform-iOS%2016%2B-blue" alt="platform">
<img src="https://img.shields.io/badge/Swift-5-orange" alt="swift">
<img src="https://img.shields.io/badge/UI-SwiftUI-informational" alt="swiftui">
<img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-lightgrey" alt="license">
</p>

<table>
<tr><td align="center"><img src="docs/screenshots/explore.png" width="190" alt="세계 히트맵과 타임라인"><br><sub>세계 히트맵과 타임라인</sub></td><td align="center"><img src="docs/screenshots/wheel.png" width="190" alt="목적지 룰렛"><br><sub>목적지 룰렛</sub></td><td align="center"><img src="docs/screenshots/assistant.png" width="190" alt="AI 목적지 추천"><br><sub>AI 목적지 추천</sub></td><td align="center"><img src="docs/screenshots/footprint.png" width="190" alt="나의 발자취"><br><sub>나의 발자취</sub></td></tr>
<tr><td align="center"><img src="docs/screenshots/badges.png" width="190" alt="배지"><br><sub>배지</sub></td><td align="center"><img src="docs/screenshots/themes.png" width="190" alt="색상 테마"><br><sub>색상 테마</sub></td><td align="center"><img src="docs/screenshots/detail.png" width="190" alt="유산 상세와 방문 기록"><br><sub>유산 상세와 방문 기록</sub></td></tr>
</table>

## 소개

세계유산 산책은 유네스코 세계유산 목록의 1,273곳 전체를 확대·축소할 수 있는 한 장의 세계 지도에 담았습니다. 먼저 전 세계 히트맵을 살펴보고, 궁금한 나라를 탭하면 그 나라의 유산이 나타납니다. 유산마다 등재 연도, 등재 기준, 역사와 문화 소개가 있습니다. 어디로 갈지 정하기 어려울 때는 룰렛에 맡기거나 한 문장으로 원하는 여행을 알려 주세요.

앱 전체를 SwiftUI와 MapKit으로 작성했으며, 서드파티 라이브러리나 자체 서버를 쓰지 않습니다. 목록 데이터는 앱에 포함되어 있고, AI 추천은 기기에서 동작합니다.

## 기능

### 무료

- **세계 히트맵**: 직접 그리는 커널 밀도 히트 레이어이며, 확대하면 묶음 표시되는 유산 핀으로 바뀝니다. 전체, 문화, 자연, 복합, 위험에 처한 유산으로 전환할 수 있습니다.
- **국가별 지도**: 나라를 탭하면 그 나라의 유산 분포와 카드 목록을 보여 줍니다.
- **유산 상세**: 등재 연도, 종류, 등재 기준, 소개, 미니 지도를 제공하며 지도 앱과 유네스코 공식 페이지로 이동할 수 있습니다.
- **목적지 룰렛**: 지역, 종류, ‘가고 싶은 곳’ 목록에서 무작위로 고릅니다. 후보 수는 5~30개로 조절할 수 있습니다.
- **목록**: 1,273곳 전체를 검색, 필터, 정렬할 수 있습니다.
- **주변 유산**: 현재 위치에서 직선거리가 가까운 순으로 보여 줍니다.
- **가고 싶은 곳 / 방문함**: 방문마다 날짜, 한 줄 메모, 사진을 남길 수 있습니다.
- **목적지 추천**: 일수, 종류, 지역, 거리에 맞춰 함께 돌기 좋은 유산 묶음을 추천합니다.
- **다섯 가지 언어**: 중국어 간체, 중국어 번체, 영어, 일본어, 한국어를 지원합니다. 유산 이름과 소개도 모두 현지화되어 있으며, 시스템 언어를 따르거나 따로 설정할 수 있습니다.
- **오늘의 유산**: 매일 알림과 홈 화면 위젯을 제공합니다.

### Pro (구독)

- **AI 여행 도우미**: 여행 계획을 한 문장으로 입력하면 기기의 Apple Intelligence(Foundation Models)가 조건으로 바꾸고 추천 이유를 작성합니다. 모델은 이해와 설명만 맡고 유산은 항상 앱이 목록에서 고르므로, 없는 장소가 나오지 않습니다.
- **여행 일정 계획**: 여러 유산을 경로로 묶고 가까운 순서로 정렬하며 일수와 거리를 추정합니다. 캘린더 파일로 내보내거나 지도 앱에서 열 수 있습니다.
- **조건 룰렛**: 거리, 계절, 방문 여부로 걸러내고 여러 룰렛을 저장할 수 있습니다.
- **도착 알림과 자동 체크인**: 유산 근처에 가면 알려 주고 자동으로 방문함으로 기록합니다.
- **맞춤 레이어와 타임라인**: 가고 싶은 곳이나 미방문만 보기, 1978년 이후 목록의 변화를 재생, 위성 지도 전환을 지원합니다.
- **돌아보기와 배지**: 연간 돌아보기, 지역·종류·달성 배지, 공유할 수 있는 발자취 포스터를 제공합니다.
- **음성 안내**, **오프라인 사진 팩**, **색상 테마**(청자, 쪽빛, 벚꽃, 먹과 금, 솔빛), **발자취 위젯**, **무제한 저장과 iCloud 동기화**.

## 배지 디자인

<p align="center"><img src="docs/design/badge_asia.svg" width="68" alt="asia"><img src="docs/design/badge_europe.svg" width="68" alt="europe"><img src="docs/design/badge_africa.svg" width="68" alt="africa"><img src="docs/design/badge_arab.svg" width="68" alt="arab"><img src="docs/design/badge_latin.svg" width="68" alt="latin"><img src="docs/design/badge_cultural.svg" width="68" alt="cultural"><img src="docs/design/badge_natural.svg" width="68" alt="natural"><img src="docs/design/badge_mixed.svg" width="68" alt="mixed"><img src="docs/design/badge_bronze.svg" width="68" alt="bronze"><img src="docs/design/badge_silver.svg" width="68" alt="silver"><img src="docs/design/badge_gold.svg" width="68" alt="gold"></p>

배지와 앱 아이콘의 벡터 원본은 [`docs/design`](docs/design)에 있습니다.

## 기술 요약

| 항목 | 구현 |
|---|---|
| UI | SwiftUI, iOS 16 이상 |
| 지도 | MapKit(`MKMapView` 래퍼). 자체 `MKOverlayRenderer`가 타일마다 가우시안 커널 밀도 히트맵을 그립니다 |
| 국가 판별 | Natural Earth 1:50m 국경 폴리곤을 포함하고 점 포함 여부를 판정합니다 |
| AI | Foundation Models 프레임워크(iOS 26 이상)의 구조화 출력. 사용할 수 없으면 조건 필터로 전환합니다 |
| 결제 | StoreKit 2. 테스트용 StoreKit 구성 파일 포함 |
| 위젯 | WidgetKit. App Group으로 앱과 약간의 상태를 공유합니다 |
| 현지화 | 가벼운 자체 문자열 테이블. 재시작 없이 언어를 바꿉니다 |
| 데이터 | 목록이 앱에 포함되어 오프라인에서도 사용할 수 있습니다 |

## 빌드와 실행

1. Xcode 26 이상이 필요합니다(개발은 Xcode 27에서 진행했습니다).
2. `WorldHeritage.xcodeproj`를 열고 iOS 16 이상 시뮬레이터를 선택해 실행합니다.
3. 디버그 빌드에는 ‘나 → 구독’에 ‘디버그: 구독 상태로 실행’ 스위치가 있어 Pro 기능을 모두 써 볼 수 있습니다.
4. AI 도우미는 iOS 26 이상과 Apple Intelligence가 켜진 기기가 필요합니다.
5. 실제 기기에서 실행하려면 Signing & Capabilities에서 본인의 팀을 선택하고 Bundle ID와 App Group을 본인 것으로 바꿔 주세요.

## 디렉터리 구조

```
WorldHeritage/            앱 본체
  Models/                 데이터 모델, 현지화, 즐겨찾기, 위치, 테마
  Map/                    히트 레이어와 지도 래퍼
  Views/                  탐색, 룰렛, 목록, 내 정보 화면
  Features/               AI 도우미, 여행 일정, 돌아보기와 배지
  Pro/                    결제와 페이월
  Resources/              목록과 국경 데이터
HeritageWidget/           홈 화면 위젯
docs/                     스크린샷과 디자인 원본
```

## 데이터 출처

- 목록, 등재 연도, 등재 기준, 소개는 [UNESCO World Heritage Centre](https://whc.unesco.org)의 공개 데이터를 사용합니다. 공식 중국어 번역이 없는 항목의 중국어와 모든 일본어·한국어 내용은 이 프로젝트에서 편역한 것으로 오류가 있을 수 있습니다. 지적해 주시면 감사하겠습니다.
- 국경 데이터는 [Natural Earth](https://www.naturalearthdata.com)에서 가져왔습니다. 탭 인식에만 사용되며 어떠한 입장도 나타내지 않습니다.
- 이 프로젝트는 유네스코와 제휴하거나 협력 관계에 있지 않습니다.

## 라이선스

소스 코드는 [PolyForm Noncommercial License 1.0.0](LICENSE.md)으로 공개합니다. 학습, 수정, 개인적 용도 등 비상업적 목적으로 자유롭게 사용할 수 있지만 **상업적 이용은 허용되지 않습니다**. App Store 출시를 포함한 상업적 이용 권리는 저작자가 보유합니다. 앱에 포함된 제3자 데이터는 이 라이선스의 적용 대상이 아닙니다. 자세한 내용은 [NOTICE](NOTICE)를 참고하세요.

## Star 추이

[![Star History Chart](https://api.star-history.com/svg?repos=DecHHts/WorldHeritage&type=Date)](https://star-history.com/#DecHHts/WorldHeritage&Date)
