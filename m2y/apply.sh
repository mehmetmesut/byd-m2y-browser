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

echo "--- M2Y: done"
