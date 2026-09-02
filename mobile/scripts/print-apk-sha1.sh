#!/usr/bin/env bash
# Prints SHA-1 certificate fingerprint from a signed Android APK (v1/v2/v3).
set -euo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"

if [ ! -f "$APK" ]; then
  echo "::error::APK not found: $APK"
  exit 1
fi

echo "=== APK signing certificate (use SHA-1 in Google Cloud Android OAuth client) ==="
echo "APK: $APK"
echo ""

extract_sha1() {
  grep -iE "SHA-?1" | head -5 || true
}

FOUND=0

# Method 1: apksigner (best for modern APK signature schemes)
if [ -n "${ANDROID_HOME:-}" ]; then
  APKSIGNER="$(find "$ANDROID_HOME/build-tools" -name apksigner -type f 2>/dev/null | sort -V | tail -1 || true)"
  if [ -n "$APKSIGNER" ]; then
    echo "--- apksigner verify --print-certs ---"
    if APKSIGNER_OUT="$("$APKSIGNER" verify --print-certs "$APK" 2>&1)"; then
      echo "$APKSIGNER_OUT"
      if echo "$APKSIGNER_OUT" | grep -qiE "SHA-?1"; then
        FOUND=1
        echo ""
        echo ">>> COPY THIS SHA-1 INTO GOOGLE CLOUD → SpendWise Android OAuth client <<<"
        echo "$APKSIGNER_OUT" | extract_sha1
      fi
    else
      echo "$APKSIGNER_OUT"
    fi
    echo ""
  fi
fi

# Method 2: extract META-INF cert and use keytool
if [ "$FOUND" -eq 0 ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  if unzip -q -j "$APK" "META-INF/*.RSA" -d "$TMP" 2>/dev/null ||
     unzip -q -j "$APK" "META-INF/*.DSA" -d "$TMP" 2>/dev/null ||
     unzip -q -j "$APK" "META-INF/*.EC" -d "$TMP" 2>/dev/null; then
    CERT="$(find "$TMP" -maxdepth 1 -type f | head -1)"
    if [ -n "$CERT" ]; then
      echo "--- keytool -printcert (META-INF signature) ---"
      KEYTOOL_OUT="$(keytool -printcert -file "$CERT" 2>&1)"
      echo "$KEYTOOL_OUT"
      if echo "$KEYTOOL_OUT" | grep -qiE "SHA-?1"; then
        FOUND=1
        echo ""
        echo ">>> COPY THIS SHA-1 INTO GOOGLE CLOUD → SpendWise Android OAuth client <<<"
        echo "$KEYTOOL_OUT" | extract_sha1
      fi
      echo ""
    fi
  fi
fi

# Method 3: legacy jarfile (older APKs)
if [ "$FOUND" -eq 0 ]; then
  echo "--- keytool -printcert -jarfile (legacy) ---"
  JAR_OUT="$(keytool -printcert -jarfile "$APK" 2>&1 || true)"
  echo "$JAR_OUT"
  if echo "$JAR_OUT" | grep -qiE "SHA-?1"; then
    FOUND=1
    echo ""
    echo ">>> COPY THIS SHA-1 INTO GOOGLE CLOUD → SpendWise Android OAuth client <<<"
    echo "$JAR_OUT" | extract_sha1
  fi
  echo ""
fi

if [ "$FOUND" -eq 0 ]; then
  echo "::error::Could not extract SHA-1 from APK. APK may be unsigned or use an unsupported signature format."
  exit 1
fi

echo "=== Package name in Google Cloud must be: com.spendwise.mobile ==="
