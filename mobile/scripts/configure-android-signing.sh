#!/bin/bash
# Patches Android release signing when keystore secrets are present.
set -euo pipefail
cd "$(dirname "$0")/.."

GRADLE_FILE="android/app/build.gradle.kts"

if [ ! -f android/app/release.keystore ]; then
  echo "No release keystore — skipping signing config"
  exit 0
fi

if [ ! -f "$GRADLE_FILE" ]; then
  echo "Expected $GRADLE_FILE not found"
  exit 1
fi

cat > android/key.properties <<EOF
storePassword=${KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=release.keystore
EOF

if grep -q 'signingConfigs.getByName("release")' "$GRADLE_FILE"; then
  echo "Release signing already configured"
  exit 0
fi

python3 <<'PY'
from pathlib import Path

gradle = Path("android/app/build.gradle.kts")
text = gradle.read_text()

signing_block = '''
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
'''

if "keystoreProperties" not in text:
    text = signing_block + "\n" + text

old = '            signingConfig = signingConfigs.getByName("debug")'
new = '''            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }'''

if old not in text:
    raise SystemExit("Could not find default release signingConfig in build.gradle.kts")

text = text.replace(old, new, 1)

insert_after = "    defaultConfig {"
signing_configs = '''
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
'''
if 'create("release")' not in text:
    idx = text.find(insert_after)
    if idx == -1:
        raise SystemExit("Could not locate defaultConfig block")
    text = text[:idx] + signing_configs + "\n" + text[idx:]

gradle.write_text(text)
print("Release signing configured in build.gradle.kts")
PY
