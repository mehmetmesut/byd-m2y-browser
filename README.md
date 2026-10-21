# M2Y Browser

**BYD Araçları İçin Geliştirilmiştir.**

Chromium tabanlı, BYD DiLink (Android 10, arm64, 1920×1080 / 240 dpi yatay ekran) için sadeleştirilmiş tarayıcı.

| Katman | Kaynak |
|---|---|
| Motor | Chromium (tag `build/RELEASE`'deki sürüm) |
| Yama seti | [Cromite](https://github.com/uazo/cromite) — reklam engelleme (eyeo/Adblock Plus motoru), gizlilik ve sadeleştirme yamaları, GPL-3.0 |
| Derleme hattı | [ungoogled-chromium-android](https://github.com/ungoogled-software/ungoogled-chromium-android) — GitHub'ın ücretsiz çalıştırıcılarında parçalı (relay) derleme, GPL-3.0 |
| M2Y katmanı | `m2y/apply.sh` (marka, Türkçe reklam listeleri, tr + en-US, 240 dpi), `m2y.gn_args` |

## Derleme

Derleme GitHub Actions üzerinde yapılır: `build-hosted.yml` → hazırlık işi Chromium kaynağını indirir, Cromite yamalarını `git am` ile uygular, M2Y düzenlemelerini yapar ve `gn gen` çalıştırır; sonraki işler 5,5 saatlik parçalar hâlinde `ninja` çalıştırıp derleme ağacını artifact olarak birbirine devreder. Çıktı: `release-arm64` artifact'ındaki imzasız `M2YBrowser_<sürüm>_arm64.apk`; imza bu depo dışında, M2Y anahtarıyla yapılır.

## Lisans

GPL-3.0 (bkz. `LICENSE.md`). Chromium BSD, Cromite ve ungoogled-chromium-android GPL-3.0 lisanslıdır; atıflar korunmuştur.
