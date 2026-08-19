#!/usr/bin/env bash
# ============================================================================
#  AFRAH COMPTA — construction des applications Windows et Android
#
#  SOURCE UNIQUE : app/www/index.html
#  NUMERO DE VERSION UNIQUE : le champ "version" de app/package.json
#
#  Pour publier une mise a jour :
#     1. modifier app/www/index.html
#     2. augmenter "version" dans app/package.json  (ex. 1.0.0 -> 1.1.0)
#     3. ./build.sh tout
#     4. distribuer les fichiers produits dans dist/
#
#  Usage :  ./build.sh windows | ./build.sh android | ./build.sh tout
# ============================================================================
set -e
PROJET="$(cd "$(dirname "$0")" && pwd)"
OUTILS="C:/Users/Henry/afrah-build"
export JAVA_HOME="$OUTILS/jdk"
export ANDROID_HOME="$OUTILS/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"
mkdir -p "$PROJET/dist"

VERSION=$(cd "$PROJET" && node -p "require('./app/package.json').version")
# versionCode Android : entier croissant obligatoire, derive de la version
VCODE=$(cd "$PROJET" && node -p "const [a,b,c]=require('./app/package.json').version.split('.').map(Number); a*10000+b*100+c")
echo "Version : $VERSION  (versionCode Android : $VCODE)"

construire_windows() {
  echo "== Windows =="
  cd "$PROJET/app"
  CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --win nsis --x64 \
    --config.win.signAndEditExecutable=false --publish never
  cp "$PROJET/app/release/AFRAH COMPTA Setup $VERSION.exe" \
     "$PROJET/dist/AFRAH-COMPTA-Windows-$VERSION.exe"
  echo "-> dist/AFRAH-COMPTA-Windows-$VERSION.exe"
}

construire_android() {
  echo "== Android =="
  rm -rf "$OUTILS/mobile/www"
  cp -r "$PROJET/app/www" "$OUTILS/mobile/www"
  # report du numero de version dans le projet Android
  GRADLE_FILE="$OUTILS/mobile/android/app/build.gradle" node -e "
    const fs=require('fs');const p=process.env.GRADLE_FILE;
    let s=fs.readFileSync(p,'utf8');
    s=s.replace(/versionCode\s+\d+/,'versionCode $VCODE');
    s=s.replace(/versionName\s+\"[^\"]*\"/,'versionName \"$VERSION\"');
    fs.writeFileSync(p,s);"
  cd "$OUTILS/mobile"
  npx cap sync android
  cd android
  ./gradlew.bat assembleDebug --no-daemon -q
  cp app/build/outputs/apk/debug/app-debug.apk "$PROJET/dist/AFRAH-COMPTA-Android-$VERSION.apk"
  # controle : l'APK doit porter la cle permanente, sinon les mises a jour casseront
  EMPREINTE=$("$ANDROID_HOME/build-tools/35.0.0/apksigner.bat" verify --print-certs \
    "$PROJET/dist/AFRAH-COMPTA-Android-$VERSION.apk" 2>/dev/null | grep -o "CN=AFRAH COMPTA" | head -1)
  if [ "$EMPREINTE" = "CN=AFRAH COMPTA" ]; then
    echo "-> dist/AFRAH-COMPTA-Android-$VERSION.apk  (signe avec la cle permanente)"
  else
    echo "!! ATTENTION : l'APK n'est PAS signe avec la cle permanente."
    echo "!! Les mises a jour seraient refusees par Android. Build interrompu."
    exit 1
  fi
}

case "${1:-tout}" in
  windows) construire_windows ;;
  android) construire_android ;;
  tout)    construire_windows; construire_android ;;
  *) echo "Usage : ./build.sh [windows|android|tout]"; exit 1 ;;
esac
echo "Termine — fichiers dans dist/"
