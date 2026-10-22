# M2Y Browser

**A fast, ad-blocking Chromium browser for the BYD Seal U DM-i head unit.**
Developed by **Yeşil Dönüşüm Mühendisi - M2Y** and shared free for every BYD owner.

[Türkçe açıklama aşağıda](#türkçe) · Downloads: **[byd.mehmetmesut.com](https://byd.mehmetmesut.com)**

---

## Why it exists

The built-in BYD browser is an old WebView shell, and mainstream browsers are heavy on the head unit and assume Google services. M2Y Browser builds current Chromium with the privacy and ad-blocking patch set of [Cromite](https://github.com/uazo/cromite), then trims it for one screen and one car:

| Head unit | Design decision |
|---|---|
| Android 10 (API 29), arm64, no Google services | Cromite's de-Googled Chromium: no Google sync, no Safe Browsing pings, no Discover feed, no prefetch/preload |
| Qualcomm SM6125, 8 GB RAM | Ad and tracker blocking built into the engine (eyeo/Adblock Plus core) instead of an extension; no debug symbols |
| Turkish driver | Turkish and English (US) UI only; EasyList, anti-circumvention and **Turkish Filters** subscribed on first run |
| 1920×1080 at 240 dpi | Only mdpi/hdpi/xhdpi drawables shipped (tvdpi/xxhdpi/xxxhdpi dropped) for a smaller APK |

## What the build does

| Layer | Source |
|---|---|
| Engine | Chromium, the tag Cromite is pinned to (see `.build_config`: `chromium_version`, `cromite_commit`) |
| Patch set | Cromite, applied with `git am` (list minus `m2y/skip_patches.txt`) |
| M2Y layer | `m2y/apply.sh` (name, package `com.m2y.browser`, Turkish filter list on first run, tr + en-US locales, 240 dpi resources, M2Y launcher icon from `m2y/res`), `m2y.gn_args` |
| Build pipeline | GitHub Actions relay derived from ungoogled-chromium-android: a prep job fetches and patches the tree and runs `gn gen`; up to eight 4.5-hour jobs run `ninja` and pass the build tree on as an artifact (36 h ceiling) |

Cloud builds are signed with Chromium's public debug key and released as drafts; the published APK is re-signed with the M2Y key outside this repository. An `x64` target exists only for testing in the Android emulator.

## Install

```
adb connect <car-ip>:5555
adb install -r M2YBrowser_<version>_arm64.apk
```

## Network traffic

Besides the pages you open: filter list updates (`easylist-downloads.adblockplus.org`, `uazo.github.io/cromite`) and Cromite's component updater. No telemetry.

## Licence and credits

- **Chromium** — BSD-3-Clause, © The Chromium Authors (notices in `chrome://credits` inside the app).
- **Cromite** — GPL-3.0, uazo and contributors, continuing Bromite by csagan5; includes the eyeo Adblock Plus engine.
- **ungoogled-chromium-android** — GPL-3.0, the build pipeline this repository is derived from.
- Filter lists: EasyList, Turkish Filters and their authors.
- M2Y build scripts and changes © 2026 Yeşil Dönüşüm Mühendisi - M2Y, GPL-3.0 ([LICENSE.md](LICENSE.md)).

**Not affiliated with Google, the Chromium project, Cromite or BYD.**

---

## Türkçe

**BYD Seal U DM-i multimedya ekranı için hızlı, reklam engelleyen Chromium tarayıcı.**
**Yeşil Dönüşüm Mühendisi - M2Y** tarafından kendi aracım için geliştirildi ve tüm BYD sahiplerinin kullanımına ücretsiz sunuldu.

- Güncel Chromium + **Cromite** yama seti: Google'sız, Discover/önceden yükleme/arka plan senkronu yok.
- Motora gömülü reklam ve izleyici engelleme; ilk açılışta **Türkçe Filtreler** dâhil listeler etkin.
- Yalnız Türkçe ve İngilizce arayüz, yalnız 240 dpi'ye uygun görseller → daha küçük APK.
- GitHub'ın ücretsiz sunucularında, herkesin doğrulayabileceği açık bir hatla derlenir; yayınlanan APK M2Y anahtarıyla imzalanır.

Kurulum: `adb install -r M2YBrowser_<sürüm>_arm64.apk` — indirme ve adım adım rehber: **[byd.mehmetmesut.com](https://byd.mehmetmesut.com)**
Lisans: GPL-3.0 (Chromium BSD-3, Cromite ve ungoogled-chromium-android GPL-3.0; atıflar korunmuştur). Google, Chromium, Cromite ya da BYD ile bağlantılı değildir.
