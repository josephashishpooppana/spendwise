#!/bin/bash
# Patches Android release signing when keystore secrets are present.
set -e
cd "$(dirname "$0")/.."

if [ ! -f android/app/release.keystore ]; then
  echo "No release keystore — skipping signing config"
  exit 0
fi

cat > android/key.properties <<EOF
storePassword=${KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=release.keystore
EOF

# Append signing config if not already present
if ! grep -q 'release.keystore' android/app/build.gradle 2>/dev/null; then
  cat >> android/app/build.gradle <<'GRADLE'

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
GRADLE
fi

echo "Release signing configured"
