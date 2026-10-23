<p align="center"><img src="docs/logo.png" width="128" height="128" alt="M2Y Browser"></p>
<h1 align="center">M2Y Browser</h1>
<p align="center"><b>A Chromium browser with built-in ad blocking, made for the BYD multimedia screen.</b><br><sub>BYD multimedya ekranı için dâhili reklam engelleyicili Chromium tarayıcı · Браузер на Chromium со встроенной блокировкой рекламы для мультимедийного экрана BYD</sub></p>
<p align="center">
  <img alt="Android 10" src="https://img.shields.io/badge/Android-10%20%28API%2029%29-3ddc84">
  <img alt="arm64" src="https://img.shields.io/badge/ABI-arm64--v8a-555">
  <img alt="no ads" src="https://img.shields.io/badge/ads-none-eb6834">
  <img alt="licence" src="https://img.shields.io/github/license/mehmetmesut/byd-m2y-browser?color=6250d6">
</p>
<p align="center">
  <a href="https://github.com/mehmetmesut/byd-m2y-browser/actions"><b>🛠 Coming soon – build in progress</b></a> ·
  <a href="https://byd.mehmetmesut.com">byd.mehmetmesut.com</a> ·
  <a href="https://github.com/mehmetmesut/byd-m2y">⭐ All M2Y apps for BYD</a>
</p>

<details open>
<summary><b>🇬🇧 English</b></summary>

### Why this app

I built my apps first for **my own BYD SEAL U DM-i**, because the store apps did not fit the car: ads, Google Play dependencies, phone and TV layouts, heavy on the CPU. The built-in BYD browser is an old WebView shell, and mainstream browsers are heavy on a head unit and expect Google services. M2Y Browser is current Chromium with the privacy and ad-blocking patch set of [Cromite](https://github.com/uazo/cromite), trimmed for one screen and one car. I then made my apps installable on **BYD multimedia screens (DiLink)** and share them **free, without ads, without tracking**, written to use **as little of the head unit's CPU, RAM and storage as possible**.

> **Status:** there is no APK yet. The cloud build is being fixed; follow it on the [Actions page](https://github.com/mehmetmesut/byd-m2y-browser/actions). Everything below describes what the repository builds.

### Highlights

- **Real Chromium.** Chromium `153.0.8010.37` (the tag Cromite's patch set is maintained for) plus Cromite's patches, not a WebView shell.
- **Ad blocking in the engine.** Cromite's built-in blocker instead of an extension; the **Turkish Filters** list is subscribed on first run.
- **No Google services.** Cromite's de-Googled patch set; nothing in the build needs Google Play services.
- **Only what the car needs.** Turkish and English (US) resources only, drawables for the 240 dpi screen only, no debug symbols.
- **Own identity.** App name "M2Y Browser", package `com.m2y.browser`, M2Y launcher icon.
- **Open build.** Built on GitHub's free runners by a public workflow, or on your own Linux machine.

### Features

- Chromium engine with Cromite's privacy hardening and its built-in ad and tracker blocking.
- On first run the ad-block subscriptions Cromite ships are set up, and **Turkish Filters** is always subscribed (upstream only does so when the device locale is Turkish). Cromite's "experimental filters" list is not subscribed automatically.
- Interface in **Turkish and English (US)** only; the user-visible name "Cromite" is replaced by "M2Y Browser" in the app label, bookmarks and search entries and in translatable strings.
- Package name `com.m2y.browser`, so it installs next to other Chromium-based browsers.
- Launcher icon in M2Y style, including the Android 13+ themed icon.
- Builds: `arm64` for the car; `x64` only for testing in the Android emulator (`arm` is also accepted by the build script, but is not the car's target).

### Built for the head unit

| Head unit fact | Design decision |
|---|---|
| Android 10 (API 29), arm64-v8a, no Google services | Cromite's de-Googled Chromium, arm64 build (`target_cpu="arm64"`) |
| Qualcomm SM6125, 8 GB RAM | Ad blocking built into the engine instead of an extension; `symbol_level = 0`, no debug fission, no linker map |
| Turkish driver | Only `tr` and `en-US` locales packaged; Turkish Filters on at first run |
| 1920×1080 at 240 dpi | Drawables for tvdpi and xxhdpi dropped (xxxhdpi is already excluded upstream); mdpi/hdpi/xhdpi kept as fallbacks; launcher icon shipped in hdpi and xhdpi |
| Landscape touch screen, no phone shell | A normal Chromium UI; no extra services are added by M2Y |

Honest note: PGO profiles for android-arm64 are not public, so the first builds go without PGO (`chrome_pgo_phase = 0`). That costs some speed, never correctness.

### Install

Once an APK is published (file name follows the pattern `M2YBrowser_153.0.8010.37-m2y1_arm64.apk`), install it with wireless ADB enabled on the head unit:

```
adb connect <car-ip>:5555
adb install -r M2YBrowser_153.0.8010.37-m2y1_arm64.apk
```

- Windows one-click installer for M2Y apps: https://byd.mehmetmesut.com/m2y-kurulum.cmd (asks the car's IP, downloads Google's platform-tools if missing, downloads the chosen apps, verifies SHA-256, installs).
- Direct install from the car's own browser only works on head units whose **stock BYD package installer has been unlocked** (the stock one blocks third-party APKs with a "driving safety" notice). This project does not distribute BYD files.
- After installing, the SealNav/stock launcher may need a restart to show the new icon.
- All M2Y APKs are meant to be signed with the same M2Y key, so updates install over the previous version and keep settings.

### Privacy & permissions

- M2Y adds **no tracking, no analytics and no ads**. Besides the pages you open, the browser downloads its ad-block filter lists from their publishers, as Cromite does.
- The Android manifest is Cromite's; M2Y changes only the app label and the package name. M2Y adds no permission of its own. Chromium asks for camera, microphone or location per site, at the moment a page requests it.
- The cloud build is signed with Chromium's public debug key and published only as a draft; a release APK is re-signed with the M2Y key outside this repository.

### Compatibility

Designed and tested on the BYD SEAL U DM-i (DiLink 3.0). Other BYD models with an Android 10+ arm64 multimedia screen are expected to work but are not tested.

### Build from source

**Cloud (GitHub Actions, free `ubuntu-latest` runners).** The workflow `M2Y Browser build` starts on a tag such as `153.0.8010.37-m2y1` or by hand (Actions → Run workflow; architecture `arm64`, `arm` or `x64`).

| Stage | What it does |
|---|---|
| `prep` | Fetches the pinned Cromite commit and the Chromium tag, syncs dependencies, applies Cromite's patches with `git am`, runs `m2y/apply.sh`, writes `args.gn` and runs `gn gen`; saves the build tree as an artifact |
| `part-01` … `part-08` | Eight relay jobs: each restores the saved tree, runs `ninja` for up to 4.5 hours, then saves the tree again (or, when finished, collects the APK). A part only starts if the previous one reports unfinished work, so the whole build may take up to 8 × 4.5 h |
| `release` | Only when a tag or release name is given: creates a **draft pre-release** with the APK and SHA-256 sums |

A resumed build refuses to continue when `m2y/apply.sh`, `m2y.gn_args`, `build.sh` or the other inputs changed since the tree was stamped, so old and new objects are never mixed. You can also resume a failed run by giving its run id (`source_run_id`).

**On your own Linux (Debian/Ubuntu) machine** with `patch`, `ccache`, `zip`, `python3` and `perl`:

```
./build.sh --install-deps --arch arm64 --target chrome_modern_target
```

The APK appears in `apk_out/` as `M2YBrowser_<chromium_version>-m2y<revision>_<arch>.apk`. Versions and the Cromite commit are pinned in `.build_config`; Cromite patches to skip can be listed in `m2y/skip_patches.txt` (empty for now); M2Y's edits live in `m2y/apply.sh` and `m2y.gn_args`. Flags: `--prepare-only` stops before `ninja`, `--resume` continues a stamped tree.

### The story, once more

I wrote these apps for my own BYD SEAL U DM-i, because nothing in the stores respected the car: they brought ads, Google dependencies and layouts made for phones, and they used too much of the head unit. Now they are installable on BYD multimedia screens and shared free, without ads and without tracking, built to open fast, respond smoothly and use as little CPU, RAM and storage as possible. I hope M2Y Browser makes your drive a little more pleasant.

**Yeşil Dönüşüm Mühendisi - M2Y** · if it helps you, a ⭐ on the [hub repository](https://github.com/mehmetmesut/byd-m2y) is the best thank-you.

</details>

<details>
<summary><b>🇹🇷 Türkçe</b></summary>

### Bu uygulama neden var

Uygulamalarımı önce **kendi BYD SEAL U DM-i aracım** için yaptım; çünkü mağaza uygulamaları araca uymuyordu: reklam, Google Play bağımlılıkları, telefon ve TV yerleşimleri, işlemciyi yoran yapı. BYD'nin kendi tarayıcısı eski bir WebView kabuğu, yaygın tarayıcılar ise multimedya ekranı için ağır ve Google hizmetleri bekliyor. M2Y Browser, güncel Chromium'un [Cromite](https://github.com/uazo/cromite) gizlilik ve reklam engelleme yama setiyle birleştirilmiş, tek ekrana ve tek araca göre sadeleştirilmiş hâlidir. Sonra uygulamalarımı **BYD multimedya ekranlarına (DiLink)** kurulabilir hâle getirdim ve **ücretsiz, reklamsız, izlemesiz** paylaşıyorum; multimedya ünitesinin **işlemcisini, belleğini ve depolamasını olabildiğince az** kullanacak biçimde yazıldılar.

> **Durum:** henüz APK yok. Bulut derlemesi düzeltiliyor; ilerleyişi [Actions sayfasından](https://github.com/mehmetmesut/byd-m2y-browser/actions) izleyebilirsiniz. Aşağıdakiler, deponun ürettiği yapıyı anlatır.

### Öne çıkanlar

- **Gerçek Chromium.** Cromite yama setinin sürdürüldüğü etiket olan Chromium `153.0.8010.37` ve Cromite yamaları; WebView kabuğu değil.
- **Motorda reklam engelleme.** Eklenti yerine Cromite'in yerleşik engelleyicisi; ilk açılışta **Türkçe Filtreler** listesine abone olunur.
- **Google hizmeti yok.** Cromite'in Google'sızlaştırılmış yama seti; yapı Google Play hizmetlerine ihtiyaç duymaz.
- **Yalnız araca gerekenler.** Yalnız Türkçe ve İngilizce (ABD) kaynakları, yalnız 240 dpi ekran için görseller, hata ayıklama sembolü yok.
- **Kendi kimliği.** "M2Y Browser" adı, `com.m2y.browser` paketi, M2Y başlatıcı simgesi.
- **Açık derleme.** GitHub'ın ücretsiz sunucularında herkese açık bir iş akışıyla ya da kendi Linux bilgisayarınızda derlenir.

### Özellikler

- Cromite'in gizlilik sertleştirmeleri ve yerleşik reklam ile izleyici engelleyicisiyle Chromium motoru.
- İlk açılışta Cromite'in sunduğu reklam engelleme abonelikleri kurulur ve **Türkçe Filtreler** her zaman abone edilir (özgün yazılım bunu yalnız cihaz dili Türkçe ise yapar). Cromite'in "deneysel filtreler" listesi kendiliğinden eklenmez.
- Arayüz yalnız **Türkçe ve İngilizce (ABD)**; kullanıcıya görünen "Cromite" adı uygulama etiketinde, yer imlerinde, arama girdilerinde ve çevrilebilir metinlerde "M2Y Browser" olarak değiştirilir.
- Paket adı `com.m2y.browser`; başka Chromium tabanlı tarayıcılarla yan yana kurulabilir.
- M2Y tarzı başlatıcı simgesi; Android 13+ temalı simge dâhil.
- Yapılar: araç için `arm64`; `x64` yalnızca Android emülatöründe sınama içindir (`arm` derleme betiğince kabul edilir, ancak aracın hedefi değildir).

### Multimedya ekranı için tasarlandı

| Ünite gerçeği | Tasarım kararı |
|---|---|
| Android 10 (API 29), arm64-v8a, Google hizmeti yok | Cromite'in Google'sızlaştırılmış Chromium'u, arm64 derleme (`target_cpu="arm64"`) |
| Qualcomm SM6125, 8 GB RAM | Eklenti yerine motorda reklam engelleme; `symbol_level = 0`, hata ayıklama ayrıştırması ve bağlayıcı haritası yok |
| Türkçe konuşan sürücü | Yalnız `tr` ve `en-US` dilleri pakete girer; Türkçe Filtreler ilk açılışta açık |
| 240 dpi'de 1920×1080 | tvdpi ve xxhdpi görselleri atıldı (xxxhdpi özgün yapıda zaten dışarıda); mdpi/hdpi/xhdpi yedek olarak kalır; başlatıcı simgesi hdpi ve xhdpi olarak gelir |
| Yatay dokunmatik ekran, telefon kabuğu yok | Olağan Chromium arayüzü; M2Y ek hizmet eklemez |

Açık not: android-arm64 için PGO profilleri herkese açık değil; bu yüzden ilk yapılar PGO'suz derlenir (`chrome_pgo_phase = 0`). Bu biraz hız kaybettirir, doğruluğu asla etkilemez.

### Kurulum

APK yayımlandığında (dosya adı kalıbı `M2YBrowser_153.0.8010.37-m2y1_arm64.apk`), multimedya ünitesinde kablosuz ADB açıkken kurun:

```
adb connect <araç-ip>:5555
adb install -r M2YBrowser_153.0.8010.37-m2y1_arm64.apk
```

- M2Y uygulamaları için Windows tek tık kurucu: https://byd.mehmetmesut.com/m2y-kurulum.cmd (aracın IP'sini sorar, yoksa Google'ın platform-tools'unu indirir, seçilen uygulamaları indirir, SHA-256'yı doğrular, kurar).
- Aracın kendi tarayıcısından doğrudan kurulum yalnız **BYD'nin özgün paket yükleyicisinin kilidi açılmış** ünitelerde çalışır (özgün yükleyici üçüncü taraf APK'leri "sürüş güvenliği" uyarısıyla engeller). Bu proje BYD dosyası dağıtmaz.
- Kurulumdan sonra yeni simgenin görünmesi için SealNav/özgün başlatıcının yeniden başlatılması gerekebilir.
- Tüm M2Y APK'leri aynı M2Y anahtarıyla imzalanır; böylece güncellemeler önceki sürümün üzerine kurulur ve ayarlar korunur.

### Gizlilik ve izinler

- M2Y **izleme, analiz ve reklam eklemez**. Açtığınız sayfalar dışında tarayıcı, Cromite'in yaptığı gibi, reklam engelleme filtre listelerini yayıncılarından indirir.
- Android bildirim dosyası (manifest) Cromite'indir; M2Y yalnız uygulama etiketini ve paket adını değiştirir, kendi izni eklemez. Chromium kamera, mikrofon ya da konum iznini siteye göre, sayfa istediği anda sorar.
- Bulut yapısı Chromium'un herkese açık hata ayıklama anahtarıyla imzalanır ve yalnız taslak olarak yayımlanır; yayın APK'si bu depo dışında M2Y anahtarıyla yeniden imzalanır.

### Uyumluluk

BYD SEAL U DM-i (DiLink 3.0) üzerinde tasarlandı ve denendi. Android 10+ arm64 multimedya ekranlı diğer BYD modellerinin de çalışması beklenir, ancak denenmemiştir.

### Kaynaktan derleme

**Bulut (GitHub Actions, ücretsiz `ubuntu-latest` sunucuları).** `M2Y Browser build` iş akışı `153.0.8010.37-m2y1` gibi bir etiketle ya da elle (Actions → Run workflow; mimari `arm64`, `arm` veya `x64`) başlar.

| Aşama | Ne yapar |
|---|---|
| `prep` | Sabitlenmiş Cromite işlemesini ve Chromium etiketini çeker, bağımlılıkları eşler, Cromite yamalarını `git am` ile uygular, `m2y/apply.sh` çalıştırır, `args.gn` yazar ve `gn gen` çalıştırır; derleme ağacını artefakt olarak saklar |
| `part-01` … `part-08` | Sekiz aktarmalı iş: her biri saklanan ağacı geri yükler, 4,5 saate kadar `ninja` çalıştırır, sonra ağacı yeniden saklar (bittiyse APK'yi toplar). Bir bölüm yalnız öncekinin işi bitmemişse başlar; yani derleme en çok 8 × 4,5 saat sürebilir |
| `release` | Yalnız etiket ya da yayın adı verilmişse: APK ve SHA-256 toplamlarıyla **taslak ön sürüm** oluşturur |

Devam eden bir derleme, ağaç damgalandıktan sonra `m2y/apply.sh`, `m2y.gn_args`, `build.sh` ya da diğer girdiler değişmişse sürmeyi reddeder; böylece eski ve yeni nesneler karışmaz. Başarısız bir çalıştırmayı, kimliğini (`source_run_id`) vererek de sürdürebilirsiniz.

**Kendi Linux (Debian/Ubuntu) bilgisayarınızda**; `patch`, `ccache`, `zip`, `python3` ve `perl` gerekir:

```
./build.sh --install-deps --arch arm64 --target chrome_modern_target
```

APK, `apk_out/` klasöründe `M2YBrowser_<chromium_version>-m2y<revizyon>_<mimari>.apk` adıyla çıkar. Sürümler ve Cromite işlemesi `.build_config` içinde sabittir; atlanacak Cromite yamaları `m2y/skip_patches.txt` dosyasına yazılabilir (şimdilik boş); M2Y düzenlemeleri `m2y/apply.sh` ve `m2y.gn_args` içindedir. Seçenekler: `--prepare-only` `ninja`'dan önce durur, `--resume` damgalı ağaçta devam eder.

### Hikâye, bir kez daha

Bu uygulamaları kendi BYD SEAL U DM-i aracım için yazdım; çünkü mağazalardaki hiçbir şey araca saygı göstermiyordu: reklam, Google bağımlılığı ve telefona göre yapılmış yerleşimler getiriyor, multimedya ünitesini gereğinden fazla yoruyorlardı. Şimdi BYD multimedya ekranlarına kurulabiliyor, ücretsiz, reklamsız ve izlemesiz paylaşılıyor; hızlı açılacak, dokunuşa akıcı yanıt verecek, işlemciyi, belleği ve depolamayı olabildiğince az kullanacak biçimde yapıldılar. M2Y Browser yolculuğunuzu biraz daha keyifli kılsın.

**Yeşil Dönüşüm Mühendisi - M2Y** · işinize yaradıysa [ana depoya](https://github.com/mehmetmesut/byd-m2y) bir ⭐ bırakmanız en güzel teşekkürdür.

</details>

<details>
<summary><b>🇷🇺 Русский</b></summary>

### Зачем это приложение

Свои приложения я сначала сделал для **собственного BYD SEAL U DM-i**, потому что приложения из магазинов не подходили автомобилю: реклама, зависимость от Google Play, раскладки для телефона и телевизора, высокая нагрузка на процессор. Встроенный браузер BYD — это старая оболочка WebView, а популярные браузеры тяжелы для мультимедийного блока и рассчитывают на сервисы Google. M2Y Browser — это актуальный Chromium с набором патчей [Cromite](https://github.com/uazo/cromite) для приватности и блокировки рекламы, упрощённый под один экран и один автомобиль. Затем я сделал свои приложения устанавливаемыми на **мультимедийные экраны BYD (DiLink)** и раздаю их **бесплатно, без рекламы и без слежки**; они написаны так, чтобы использовать **как можно меньше процессора, памяти и накопителя** мультимедийного блока.

> **Статус:** APK пока нет. Облачная сборка исправляется; следить за ней можно на [странице Actions](https://github.com/mehmetmesut/byd-m2y-browser/actions). Ниже описано то, что собирает этот репозиторий.

### Главное

- **Настоящий Chromium.** Chromium `153.0.8010.37` (тег, под который ведётся набор патчей Cromite) плюс патчи Cromite — а не оболочка WebView.
- **Блокировка рекламы в движке.** Встроенный блокировщик Cromite вместо расширения; при первом запуске подключается список **Turkish Filters**.
- **Без сервисов Google.** Набор патчей Cromite без Google; сборка не требует сервисов Google Play.
- **Только нужное для автомобиля.** Ресурсы только на турецком и английском (США), графика только для экрана 240 dpi, без отладочных символов.
- **Собственная идентичность.** Название «M2Y Browser», пакет `com.m2y.browser`, значок M2Y.
- **Открытая сборка.** Собирается публичным рабочим процессом на бесплатных серверах GitHub или на вашем компьютере с Linux.

### Возможности

- Движок Chromium с защитой приватности Cromite и его встроенным блокировщиком рекламы и трекеров.
- При первом запуске настраиваются подписки блокировки рекламы, поставляемые с Cromite, а **Turkish Filters** подключается всегда (в оригинале — только если язык устройства турецкий). Список Cromite «experimental filters» автоматически не подключается.
- Интерфейс только на **турецком и английском (США)**; видимое пользователю название «Cromite» заменено на «M2Y Browser» в названии приложения, закладках, пунктах поиска и переводимых строках.
- Имя пакета `com.m2y.browser`, поэтому приложение ставится рядом с другими браузерами на Chromium.
- Значок запуска в стиле M2Y, включая тематический значок Android 13+.
- Сборки: `arm64` для автомобиля; `x64` — только для проверки в эмуляторе Android (`arm` сценарий сборки принимает, но это не целевая платформа автомобиля).

### Создано для мультимедийного блока

| Факт о блоке | Проектное решение |
|---|---|
| Android 10 (API 29), arm64-v8a, без сервисов Google | Chromium от Cromite без Google, сборка arm64 (`target_cpu="arm64"`) |
| Qualcomm SM6125, 8 ГБ ОЗУ | Блокировка рекламы в движке вместо расширения; `symbol_level = 0`, без debug fission и без карты компоновщика |
| Водитель говорит по-турецки | В пакет входят только локали `tr` и `en-US`; Turkish Filters включены при первом запуске |
| 1920×1080 при 240 dpi | Графика tvdpi и xxhdpi удалена (xxxhdpi в оригинале уже исключена); mdpi/hdpi/xhdpi остаются запасными; значок запуска — hdpi и xhdpi |
| Горизонтальный сенсорный экран, не телефон | Обычный интерфейс Chromium; M2Y не добавляет собственных служб |

Честное замечание: профили PGO для android-arm64 не опубликованы, поэтому первые сборки идут без PGO (`chrome_pgo_phase = 0`). Это стоит немного скорости, но не влияет на корректность.

### Установка

Когда APK будет опубликован (имя файла по шаблону `M2YBrowser_153.0.8010.37-m2y1_arm64.apk`), установите его при включённом беспроводном ADB на мультимедийном блоке:

```
adb connect <ip-авто>:5555
adb install -r M2YBrowser_153.0.8010.37-m2y1_arm64.apk
```

- Установщик M2Y для Windows в один клик: https://byd.mehmetmesut.com/m2y-kurulum.cmd (спрашивает IP автомобиля, при необходимости скачивает platform-tools от Google, скачивает выбранные приложения, проверяет SHA-256 и устанавливает).
- Прямая установка из браузера автомобиля работает только на блоках, у которых **разблокирован штатный установщик пакетов BYD** (штатный блокирует сторонние APK уведомлением о «безопасности движения»). Проект не распространяет файлы BYD.
- После установки штатный лаунчер SealNav может потребовать перезапуска, чтобы показать новый значок.
- Все APK M2Y подписываются одним ключом M2Y, поэтому обновления ставятся поверх предыдущей версии и сохраняют настройки.

### Приватность и разрешения

- M2Y **не добавляет слежки, аналитики и рекламы**. Кроме открываемых вами страниц, браузер, как и Cromite, загружает списки фильтров рекламы с серверов их издателей.
- Манифест Android взят у Cromite; M2Y меняет только название приложения и имя пакета и не добавляет собственных разрешений. Chromium запрашивает доступ к камере, микрофону и геопозиции отдельно для каждого сайта — в момент, когда страница его просит.
- Облачная сборка подписывается общедоступным отладочным ключом Chromium и публикуется только как черновик; релизный APK заново подписывается ключом M2Y вне этого репозитория.

### Совместимость

Разработано и проверено на BYD SEAL U DM-i (DiLink 3.0). Другие модели BYD с мультимедийным экраном на Android 10+ (arm64), как ожидается, будут работать, но не проверялись.

### Сборка из исходников

**Облако (GitHub Actions, бесплатные серверы `ubuntu-latest`).** Рабочий процесс `M2Y Browser build` запускается по тегу вроде `153.0.8010.37-m2y1` или вручную (Actions → Run workflow; архитектура `arm64`, `arm` или `x64`).

| Этап | Что делает |
|---|---|
| `prep` | Загружает закреплённый коммит Cromite и тег Chromium, синхронизирует зависимости, применяет патчи Cromite через `git am`, запускает `m2y/apply.sh`, записывает `args.gn` и выполняет `gn gen`; сохраняет дерево сборки как артефакт |
| `part-01` … `part-08` | Восемь эстафетных заданий: каждое восстанавливает сохранённое дерево, до 4,5 часа выполняет `ninja`, затем снова сохраняет дерево (а по завершении собирает APK). Часть запускается, только если предыдущая сообщила о незавершённой работе, поэтому вся сборка может занять до 8 × 4,5 ч |
| `release` | Только если указан тег или имя релиза: создаёт **черновик пре-релиза** с APK и суммами SHA-256 |

Продолжаемая сборка отказывается идти дальше, если после отметки дерева изменились `m2y/apply.sh`, `m2y.gn_args`, `build.sh` или другие входные файлы, — так старые и новые объекты не смешиваются. Неудачный запуск можно продолжить, указав его идентификатор (`source_run_id`).

**На собственном компьютере с Linux (Debian/Ubuntu)**; нужны `patch`, `ccache`, `zip`, `python3` и `perl`:

```
./build.sh --install-deps --arch arm64 --target chrome_modern_target
```

APK появится в `apk_out/` под именем `M2YBrowser_<chromium_version>-m2y<ревизия>_<архитектура>.apk`. Версии и коммит Cromite закреплены в `.build_config`; пропускаемые патчи Cromite можно перечислить в `m2y/skip_patches.txt` (пока пуст); правки M2Y находятся в `m2y/apply.sh` и `m2y.gn_args`. Параметры: `--prepare-only` останавливается перед `ninja`, `--resume` продолжает отмеченное дерево.

### История ещё раз

Эти приложения я написал для собственного BYD SEAL U DM-i, потому что ничто в магазинах не считалось с автомобилем: приложения приносили рекламу, зависимость от Google и раскладки для телефонов и слишком нагружали мультимедийный блок. Теперь их можно установить на мультимедийные экраны BYD, и я раздаю их бесплатно, без рекламы и без слежки; они сделаны так, чтобы быстро открываться, плавно реагировать на касания и использовать как можно меньше процессора, памяти и накопителя. Надеюсь, M2Y Browser сделает ваши поездки чуть приятнее.

**Yeşil Dönüşüm Mühendisi - M2Y** · если приложение вам пригодилось, звезда ⭐ на [главном репозитории](https://github.com/mehmetmesut/byd-m2y) — лучшая благодарность.

</details>

<hr>
<p align="center"><sub>Chromium: BSD-3-Clause, © The Chromium Authors (notices in <code>chrome://credits</code>) · Cromite: GPL-3.0, uazo and contributors, continuing Bromite by csagan5, includes the eyeo Adblock Plus engine · ungoogled-chromium-android: GPL-3.0, the build pipeline this repository is derived from · Filter lists: EasyList, Turkish Filters and their authors · M2Y build scripts and changes: GPL-3.0, see <a href="LICENSE.md">LICENSE.md</a><br>Not affiliated with BYD, Google, the Chromium project or Cromite; trademarks belong to their owners. · © 2026 Yeşil Dönüşüm Mühendisi - M2Y</sub></p>
