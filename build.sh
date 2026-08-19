#!/usr/bin/env bash
# ============================================================================
#  AFRAH COMPTA — construction des applications Windows et Android
#  Source unique : app/www/index.html  (ne jamais dupliquer ce fichier)
#  Usage :  ./build.sh windows    |    ./build.sh android    |    ./build.sh tout
# ============================================================================
set -e
PROJET="$(cd "$(dirname "$0")" && pwd)"
OUTILS="C:/Users/Henry/afrah-build"
export JAVA_HOME="$OUTILS/jdk"
export ANDROID_HOME="$OUTILS/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"
mkdir -p "$PROJET/dist"

construire_windows() {
  echo "== Windows =="
  cd "$PROJET/app"
  CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --win nsis --x64 \
    --config.win.signAndEditExecutable=false --publish never
  cp "$PROJET/app/release/AFRAH COMPTA Setup 1.0.0.exe" \
     "$PROJET/dist/AFRAH-COMPTA-Windows-Installateur-1.0.0.exe"
  echo "-> dist/AFRAH-COMPTA-Windows-Installateur-1.0.0.exe"
}

construire_android() {
  echo "== Android =="
  # la source unique est recopiee vers le projet mobile avant chaque build
  rm -rf "$OUTILS/mobile/www"
  cp -r "$PROJET/app/www" "$OUTILS/mobile/www"
  cd "$OUTILS/mobile"
  npx cap sync android
  cd android
  ./gradlew.bat assembleDebug --no-daemon -q
  cp app/build/outputs/apk/debug/app-debug.apk \
     "$PROJET/dist/AFRAH-COMPTA-Android-1.0.0.apk"
  echo "-> dist/AFRAH-COMPTA-Android-1.0.0.apk"
}

case "${1:-tout}" in
  windows) construire_windows ;;
  android) construire_android ;;
  tout)    construire_windows; construire_android ;;
  *) echo "Usage : ./build.sh [windows|android|tout]"; exit 1 ;;
esac
echo "Termine."
