#!/usr/bin/env bash
# Copyright (C) 2026 Yeşil Dönüşüm Mühendisi - M2Y. SPDX-License-Identifier: GPL-3.0-only
# M2Y Browser edits, applied inside the Chromium tree AFTER Cromite's patch set.
# Plain text edits instead of .patch files, so they keep working when Cromite moves to a new Chromium tag.
# Usage: m2y/apply.sh <chromium src dir>
set -euo pipefail
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
grep -q 'M2Y: car languages only' "$LOC" || cat >> "$LOC" <<'GNI'

# M2Y: car languages only
if (is_android) {
  platform_pak_locales = []
  platform_pak_locales = [ "en-US", "tr" ]
  locales_without_pseudolocales = []
  locales_without_pseudolocales = platform_pak_locales
  locales_with_pseudolocales = []
  locales_with_pseudolocales = platform_pak_locales
  android_bundle_locales_as_resources = []
  android_bundle_locales_as_resources = [ "tr" ]
}
GNI
expect "$LOC" 'M2Y: car languages only'

echo "--- M2Y: drawables for a 240 dpi screen (keep mdpi/hdpi/xhdpi as fallbacks, drop tvdpi/xxhdpi; xxxhdpi is already dropped)"
EXC=base/android/resource_exclusions.gni
grep -qE '^common_resource_exclusion_regex = "[^"]' "$EXC" || fail "unexpected resource_exclusions.gni"
grep -q 'M2Y' "$EXC" || printf '\n# M2Y: single 240 dpi head unit\ncommon_resource_exclusion_regex += "|drawable[^/]*-(tvdpi|xxhdpi)\\b"\n' >> "$EXC"
expect "$EXC" 'tvdpi|xxhdpi'

echo "--- M2Y: done"
