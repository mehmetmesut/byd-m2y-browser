#!/usr/bin/env bash
# Copyright (C) 2026 Yeşil Dönüşüm Mühendisi - M2Y. SPDX-License-Identifier: GPL-3.0-only
# M2Y Browser edits, applied inside the Chromium tree AFTER Cromite's patch set.
# Plain text edits instead of .patch files, so they keep working when Cromite moves to a new Chromium tag.
# Usage: m2y/apply.sh <chromium src dir>
set -euo pipefail
M2Y_RES="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/res"  # before cd: the script may be called by a relative path
cd "$1"

fail() { echo "FATAL (m2y/apply.sh): $*" >&2; exit 1; }
# every edit must hit: a silent miss would ship a half-branded browser
expect() { grep -q -- "$2" "$1" || fail "'$2' not found in $1"; }

echo "--- M2Y: branding"
sed -i 's|android:label="Cromite"|android:label="M2Y Browser"|' chrome/android/java/AndroidManifest.xml
expect chrome/android/java/AndroidManifest.xml 'android:label="M2Y Browser"'
sed -i -e 's|>Cromite</string>|>M2Y Browser</string>|' \
       -e 's|>Cromite bookmarks<|>M2Y Browser yer imleri<|' \
       -e 's|>Cromite search<|>M2Y Browser arama<|' \
       -e 's|>Cromite quick action search<|>M2Y Browser hızlı arama<|' \
       chrome/android/java/res_chromium_base/values/channel_constants.xml
expect chrome/android/java/res_chromium_base/values/channel_constants.xml '>M2Y Browser</string>'
sed -i -e 's/^PRODUCT_FULLNAME=.*/PRODUCT_FULLNAME=M2Y Browser/' \
       -e 's/^PRODUCT_SHORTNAME=.*/PRODUCT_SHORTNAME=M2Y Browser/' chrome/app/theme/chromium/BRANDING
expect chrome/app/theme/chromium/BRANDING 'PRODUCT_FULLNAME=M2Y Browser'
# user-visible "Cromite" in translatable strings; URLs stay (they are lowercase "cromite")
grep -rl --include='*.grd' --include='*.grdp' 'Cromite' chrome components 2>/dev/null \
  | xargs -r perl -pi -e 's/(?<![\w\/.])Cromite(?![\w.\/])/M2Y Browser/g'
for f in chrome/android/java/res/values/values.xml \
         components/browser_ui/site_settings/android/java/res/xml/site_settings_preferences.xml; do
  [ -f "$f" ] && perl -pi -e 's/(?<![\w\/.])Cromite(?![\w.\/])/M2Y Browser/g' "$f"
done
! grep -rq --include='*.grdp' '>Restart Cromite' chrome/browser/ui/android/strings || fail "Cromite strings left in Android UI"

echo "--- M2Y: Turkish ad-block lists on by default"
SUB=components/adblock/core/subscription/subscription_config.cc
expect "$SUB" 'turkish-filters.txt'
perl -0pi -e 's/("Turkish Filters",\s*\{"tr"\},\s*SubscriptionUiVisibility::Visible,\s*)SubscriptionFirstRunBehavior::SubscribeIfLocaleMatch/$1SubscriptionFirstRunBehavior::SubscribeAtFirstRun/' "$SUB"
grep -A4 '"Turkish Filters"' "$SUB" | grep -q SubscribeAtFirstRun || fail "Turkish Filters is not SubscribeAtFirstRun"
perl -0pi -e 's/("Cromite experimental filters",\s*\{\},\s*SubscriptionUiVisibility::Visible,\s*)SubscriptionFirstRunBehavior::SubscribeAtFirstRun/$1SubscriptionFirstRunBehavior::Ignore/' "$SUB"
! grep -A4 '"Cromite experimental filters"' "$SUB" | grep -q SubscribeAtFirstRun || fail "experimental filters still on at first run"

echo "--- M2Y: languages tr + en-US only"
LOC=build/config/locales.gni
expect "$LOC" 'android_bundle_locales_as_resources'
# Appended after every rule in the file: earlier lines remove Android names (es-r419, ...) and pseudolocales
# from these lists and would fail on a short list. GN refuses to replace a nonempty list, hence the "= []".
# locales_with_pseudolocales stays full: grit asserts it against every <output> of locale_settings_linux.grd.
# Only the packaging lists are cut (repack, aapt_locale_allowlist); the extra paks are built but not shipped.
grep -q 'M2Y: car languages only' "$LOC" || cat >> "$LOC" <<'GNI'

# M2Y: car languages only
if (is_android) {
  platform_pak_locales = []
  platform_pak_locales = [ "en-US", "tr" ]
  android_bundle_locales_as_resources = []
  android_bundle_locales_as_resources = [ "tr" ]
}
GNI
expect "$LOC" 'M2Y: car languages only'
# The bundle subtracts extended_locales from our short list; filter_exclude tolerates absent items
BUN=chrome/android/modules/chrome_bundle_tmpl.gni
sed -i 's/system_image_locale_allowlist = platform_pak_locales - extended_locales/system_image_locale_allowlist = filter_exclude(platform_pak_locales, extended_locales)/' "$BUN"
expect "$BUN" 'filter_exclude(platform_pak_locales, extended_locales)'

echo "--- M2Y: drawables for a 240 dpi screen (keep mdpi/hdpi/xhdpi as fallbacks, drop tvdpi/xxhdpi; xxxhdpi is already dropped)"
EXC=base/android/resource_exclusions.gni
grep -qE '^common_resource_exclusion_regex = "[^"]' "$EXC" || fail "unexpected resource_exclusions.gni"
# mediarouter is exempt: Chromium already drops its hdpi/xhdpi animation frames, xxhdpi is the only density left
grep -q 'M2Y' "$EXC" || printf '\n# M2Y: single 240 dpi head unit\ncommon_resource_exclusion_regex += "|^(?!.*mediarouter).*drawable[^/]*-(tvdpi|xxhdpi)\\b"\n' >> "$EXC"
expect "$EXC" '(?!.*mediarouter).*drawable\[^/\]\*-(tvdpi|xxhdpi)'

echo "--- M2Y: launcher icon (hdpi = the car's 240 dpi, xhdpi fallback; Cromite's other densities removed)"
ICO=chrome/android/java/res_chromium_base
for f in app_icon layered_app_icon layered_app_icon_background; do
  for d in mdpi xxhdpi xxxhdpi; do rm -f "$ICO/mipmap-$d/$f.png"; done
  for d in hdpi xhdpi; do
    [ -f "$ICO/mipmap-$d/$f.png" ] || fail "$ICO/mipmap-$d/$f.png missing"
    cp "$M2Y_RES/mipmap-$d/$f.png" "$ICO/mipmap-$d/$f.png"
    cmp -s "$M2Y_RES/mipmap-$d/$f.png" "$ICO/mipmap-$d/$f.png" || fail "$f ($d) not replaced"
  done
done
# chrome/android/BUILD.gn lists every icon density as a source; drop the removed ones or ninja stops on missing files
expect chrome/android/BUILD.gn '"java/res_chromium_base/mipmap-mdpi/app_icon.png"'
sed -i -E '\#"java/res_chromium_base/mipmap-(mdpi|xxhdpi|xxxhdpi)/#d' chrome/android/BUILD.gn
! grep -qE '"java/res_chromium_base/mipmap-(mdpi|xxhdpi|xxxhdpi)/' chrome/android/BUILD.gn || fail "removed icons still listed in chrome/android/BUILD.gn"
# Cromite bakes its logo into the round icon's BACKGROUND (foreground = transparent shape) and draws the square icon on
# white; M2Y's layers are a plain blue background + white symbol, so both adaptive icons must use exactly these two
# layers or the launcher shows a bare blue disc (Pixel launcher prefers roundIcon; seen on Android 10, 26.10.2026)
ICONS=$(grep -rlE --include='ic_launcher.xml' --include='ic_launcher_round.xml' '<adaptive-icon' chrome/android/java || true)
[ -n "$ICONS" ] || fail "adaptive ic_launcher(_round).xml not found under chrome/android/java"
for f in $ICONS; do
  perl -0pi -e 's#(<background\b[^>]*?android:drawable=")[^"]*#${1}\@mipmap/layered_app_icon_background#s;
                s#(<foreground\b[^>]*?android:drawable=")[^"]*#${1}\@mipmap/layered_app_icon#s' "$f"
  expect "$f" 'android:drawable="@mipmap/layered_app_icon_background"'
  expect "$f" 'android:drawable="@mipmap/layered_app_icon"'
done
# Android 13+ themed icon: the foreground layer's alpha instead of Cromite's vector
[ -f "$ICO/drawable/themed_app_icon.xml" ] || fail "themed_app_icon.xml missing"
printf '<?xml version="1.0" encoding="utf-8"?>\n<bitmap xmlns:android="http://schemas.android.com/apk/res/android" android:src="@mipmap/layered_app_icon" />\n' \
  > "$ICO/drawable/themed_app_icon.xml"

echo "--- M2Y: one fixed configuration (mandatory policies, feature defaults, hidden option entries)"
# Cromite's command-line policy loader runs on every start. M2Y's policies are set directly (not via AddPolicy), so
# chrome://policy cannot switch them off; the settings UI shows them as managed and unchangeable.
POL=components/policy/core/common/policy_loader_command_line.cc
expect "$POL" '  policy_map.Set(policy::key::kEnableExperimentalPolicies,'
grep -q 'M2Y: fixed car configuration' "$POL" || perl -0pi -e 's#(\n  policy_map\.Set\(policy::key::kEnableExperimentalPolicies,)#
  // M2Y: fixed car configuration
  const auto m2y = [&policy_map](const char* name, base::Value value) {
    policy_map.Set(name, POLICY_LEVEL_MANDATORY, POLICY_SCOPE_MACHINE,
                   POLICY_SOURCE_COMMAND_LINE, std::move(value), nullptr);
  };
  // Google is the only search engine; no suggestion request per keystroke
  m2y(key::kDefaultSearchProviderEnabled, base::Value(true));
  m2y(key::kDefaultSearchProviderName, base::Value("Google"));
  m2y(key::kDefaultSearchProviderKeyword, base::Value("google.com"));
  m2y(key::kDefaultSearchProviderSearchURL,
      base::Value("https://www.google.com/search?q={searchTerms}&ie={inputEncoding}"));
  m2y(key::kSearchSuggestEnabled, base::Value(false));
  // JavaScript JIT and optimizer on (Cromite blocks JIT by default): 1 = allow
  m2y(key::kDefaultJavaScriptJitSetting, base::Value(1));
  m2y(key::kDefaultJavaScriptOptimizerSetting, base::Value(1));
  // no push, no form filling, no printing in the car: 2 = block
  m2y(key::kDefaultNotificationsSetting, base::Value(2));
  m2y(key::kPasswordManagerEnabled, base::Value(false));
  m2y(key::kAutofillAddressEnabled, base::Value(false));
  m2y(key::kAutofillCreditCardEnabled, base::Value(false));
  m2y(key::kPrintingEnabled, base::Value(false));
  base::ListValue m2y_blocked;
  m2y_blocked.Append("chrome://flags");
  m2y(key::kURLBlocklist, base::Value(std::move(m2y_blocked)));
$1#' "$POL"
expect "$POL" 'm2y(key::kDefaultSearchProviderSearchURL,'
expect "$POL" 'm2y(key::kURLBlocklist, base::Value(std::move(m2y_blocked)));'

# Feature defaults: an exact file and value per edit, so a Cromite update that moves them stops the build here
flip() {  # flip <file> <feature name> <from> <to>
  perl -0pi -e "s/(\"$2\",\\s*base::)FEATURE_$3_BY_DEFAULT/\${1}FEATURE_$4_BY_DEFAULT/" "$1"
  grep -A1 "\"$2\"," "$1" | grep -q "FEATURE_$4_BY_DEFAULT" || fail "$2 is not $4 in $1"
}
# keyboard: Chromium's own IME resize instead of Cromite's protected viewport scroll view (keyboard latency)
flip cromite_flags/third_party/blink/common/features_cc/Android-Protected-Keyboard-Geometry.inc AndroidProtectedKeyboardGeometry ENABLED DISABLED
# key events keep the real (Turkish) layout
flip ui/base/ui_base_features.cc SystemKeyboardProtection ENABLED DISABLED
# moving car, changing IP: QUIC sessions migrate (Chromium's Android default) instead of closing
CIP=cromite_flags/net/base/features_cc/Close-Sessions-On-Ip-Change.inc
flip "$CIP" CloseSessionsOnIpChange ENABLED DISABLED
sed -i '/^SET_CROMITE_FEATURE_DISABLED(kMigrateSessionsOnNetworkChangeV2);$/d' "$CIP"
! grep -q 'kMigrateSessionsOnNetworkChangeV2' "$CIP" || fail "QUIC migration still forced off in $CIP"
NETF=net/base/features.cc
perl -0pi -e 's/(#if BUILDFLAG\(IS_ANDROID\)\ninline constexpr auto kMigrateSessionsOnNetworkChangeV2Default =\n    base::)FEATURE_DISABLED_BY_DEFAULT/${1}FEATURE_ENABLED_BY_DEFAULT/' "$NETF"
grep -A2 '^#if BUILDFLAG(IS_ANDROID)$' "$NETF" | grep -A1 'kMigrateSessionsOnNetworkChangeV2Default =' | grep -q ENABLED || fail "QUIC migration default not restored in $NETF"
# tab switcher: list mode, which also turns tab snapshots off (TabContentManager snapshotsEnabled)
flip cromite_flags/chrome/browser/flags/android/chrome_feature_list_cc/tab-switcher-list-mode.inc TabSwitcherListMode DISABLED ENABLED
LST=chrome/browser/flags/android/java/src/org/chromium/chrome/browser/flags/cromite/sTabSwitcherListMode.java
sed -i 's/"TabSwitcherListMode", false);/"TabSwitcherListMode", true);/' "$LST"  # the first run, before the flag cache exists
expect "$LST" '"TabSwitcherListMode", true);'

# Options with no policy: entries hidden (code stays, so later Cromite patches keep applying)
HIDE="always_incognito proxy useragent_settings userscripts_settings force_tablet_ui move_toolbar_bottom pixel_perfect_mode
      enable_extensions_android enable_cromite_test_support act_as_webview test_gwp_asan throttle_main_thread_to_60hz
      allow_inline_update cromite_flags tabgrid_use_icons use_tab_switcher_list_mode"
XMLS=$(find chrome/android/java/res/xml components/browser_ui/accessibility/android/java/res/xml -name '*.xml')
for k in $HIDE; do
  files=$(grep -l "android:key=\"$k\"" $XMLS || true)
  [ -n "$files" ] || fail "preference '$k' not found"
  for f in $files; do
    grep -q 'xmlns:app=' "$f" || sed -i '0,/xmlns:android="[^"]*"/s##& xmlns:app="http://schemas.android.com/apk/res-auto"#' "$f"
    grep -q "android:key=\"$k\" app:isPreferenceVisible=\"false\"" "$f" ||
      sed -i "s#android:key=\"$k\"#& app:isPreferenceVisible=\"false\"#" "$f"
    expect "$f" "android:key=\"$k\" app:isPreferenceVisible=\"false\""
    expect "$f" 'xmlns:app='
  done
done

echo "--- M2Y: done"
