#!/bin/zsh
# Creates VD VR's Android release signing key – once. The password goes into the macOS keychain
# (service "vd-vr-release"), never into a file. Back up the keystore: every update needs the same key.
set -e
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}
KS="$HOME/.android/vd-vr-release.keystore"
if [ -f "$KS" ]; then echo "Den Schlüssel gibt es schon: $KS"; exit 0; fi
mkdir -p "$HOME/.android"
read -rs "PW?Neues Passwort für den VD-VR-Schlüssel (mind. 8 Zeichen): "; echo
read -rs "PW2?Noch einmal: "; echo
[ "$PW" = "$PW2" ] || { echo "Die Passwörter sind verschieden – bitte neu starten."; exit 1; }
[ ${#PW} -ge 8 ] || { echo "Zu kurz – mindestens 8 Zeichen."; exit 1; }
"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS" -alias vd-vr -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$PW" -keypass "$PW" -dname "CN=VD VR, O=NEXTPHILM, C=DE" >/dev/null
security add-generic-password -a "$USER" -s vd-vr-release -w "$PW" -U
unset PW PW2
echo "Fertig: $KS"
echo "Das Passwort liegt im Schlüsselbund (Eintrag „vd-vr-release“). Bitte den Schlüssel sichern – ohne ihn gibt es keine Updates."
