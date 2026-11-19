#!/bin/zsh
# Builds the signed release APK for the Pico: build/vd-vr-<version>-pico.apk.
# Needs the key from tools/make-release-key.sh (~/.android/vd-vr-release.keystore, password in the
# macOS keychain, entry "vd-vr-release") and the music file (music/README.md) for the full app.
set -e
cd "${0:A:h}/.."
KS=~/.android/vd-vr-release.keystore
[[ -f $KS ]] || { echo "Kein Schlüssel – zuerst tools/make-release-key.sh"; exit 1; }
[[ -f music/atlasaudio-chill-out-621545.mp3 ]] || echo "Hinweis: ohne Musikdatei (music/README.md) – App ohne Hintergrundmusik."
VER=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=vd-vr
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(security find-generic-password -s vd-vr-release -w)"
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mkdir -p build
"$GODOT" --headless --path . --export-release "Pico" "build/vd-vr-$VER-pico.apk"
unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
APKSIGNER=$(ls -d ${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/build-tools/*/apksigner 2>/dev/null | tail -1)
[[ -n $APKSIGNER ]] && "$APKSIGNER" verify --print-certs "build/vd-vr-$VER-pico.apk" | grep -E "Signer #1 certificate DN|SHA-256"
echo "Fertig: build/vd-vr-$VER-pico.apk"
