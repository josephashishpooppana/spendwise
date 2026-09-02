#!/bin/bash
# Run after `flutter create` in CI — apply SpendWise-specific Android patches.
set -euo pipefail
cd "$(dirname "$0")/.."

PACKAGE_NAME="com.spendwise.mobile"

cp scripts/proguard-rules.pro android/proguard-rules.pro

APP_GRADLE=""
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then APP_GRADLE="$f"; break; fi
done

if [ -z "$APP_GRADLE" ]; then
  echo "Could not find android/app/build.gradle(.kts)"
  exit 1
fi

# Force package name to match Google OAuth Android client (see google-setup.md).
if grep -q 'namespace' "$APP_GRADLE"; then
  sed -i "s/namespace = \"[^\"]*\"/namespace = \"$PACKAGE_NAME\"/g" "$APP_GRADLE"
fi
if grep -q 'applicationId' "$APP_GRADLE"; then
  sed -i "s/applicationId = \"[^\"]*\"/applicationId = \"$PACKAGE_NAME\"/g" "$APP_GRADLE"
fi

# sqflite + Google Sign-In need API 23+.
if grep -q 'minSdk = flutter.minSdkVersion' "$APP_GRADLE"; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = maxOf(23, flutter.minSdkVersion)/g' "$APP_GRADLE"
elif grep -qE 'minSdk = [0-9]+' "$APP_GRADLE"; then
  sed -i 's/minSdk = [0-9][0-9]*/minSdk = 23/g' "$APP_GRADLE"
elif grep -qE 'minSdkVersion [0-9]+' "$APP_GRADLE"; then
  sed -i 's/minSdkVersion [0-9][0-9]*/minSdkVersion 23/g' "$APP_GRADLE"
fi

sed -i 's/isMinifyEnabled = true/isMinifyEnabled = false/g' "$APP_GRADLE" 2>/dev/null || true
sed -i 's/isShrinkResources = true/isShrinkResources = false/g' "$APP_GRADLE" 2>/dev/null || true

echo "Android patches applied (package=$PACKAGE_NAME, minSdk 23+, minify off)"
grep -nE 'namespace|applicationId|minSdk' "$APP_GRADLE" || true
