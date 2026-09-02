#!/bin/bash
# Run after `flutter create` in CI — apply SpendWise-specific Android patches.
set -euo pipefail
cd "$(dirname "$0")/.."

cp scripts/proguard-rules.pro android/proguard-rules.pro

APP_GRADLE=""
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then APP_GRADLE="$f"; break; fi
done

if [ -z "$APP_GRADLE" ]; then
  echo "Could not find android/app/build.gradle(.kts)"
  exit 1
fi

# sqflite + Google Sign-In need API 23+
if grep -q 'minSdk' "$APP_GRADLE"; then
  sed -i 's/minSdk = [0-9]*/minSdk = 23/g' "$APP_GRADLE" 2>/dev/null || \
  sed -i 's/minSdkVersion [0-9]*/minSdkVersion 23/g' "$APP_GRADLE" || true
fi

# Avoid R8 stripping plugin classes in release builds
sed -i 's/isMinifyEnabled = true/isMinifyEnabled = false/g' "$APP_GRADLE" 2>/dev/null || true
sed -i 's/isShrinkResources = true/isShrinkResources = false/g' "$APP_GRADLE" 2>/dev/null || true

echo "Android patches applied (minSdk 23, minify off)"
