#!/usr/bin/env bash
# ============================================================================
#  AFRAH COMPTA — construction des applications Windows et Android
#
#  SOURCE UNIQUE : app/www/index.html
#  NUMERO DE VERSION UNIQUE : le champ "version" de app/package.json
#
#  ORGANISATION DES LIVRABLES :
#     dist/releases/<version>/   -> ARCHIVE PERMANENTE de chaque version.
#                                   Jamais ecrasee, jamais supprimee automatiquement.
#     dist/                      -> copie de la DERNIERE version uniquement
#                                   (pour l'envoi rapide et pour TESTER-SUR-TELEPHONE.bat)
#
#  Pour publier une mise a jour :
#     1. modifier app/www/index.html
#     2. augmenter "version" dans app/package.json  (ex. 1.2.0 -> 1.3.0)
#     3. ./build.sh tout
#     4. la version est conservee dans dist/releases/1.3.0/ pour toujours
#
#  Usage :  ./build.sh windows | ./build.sh android | ./build.sh tout
# ============================================================================
set -e
PROJET="$(cd "$(dirname "$0")" && pwd)"
OUTILS="C:/Users/Henry/afrah-build"
export JAVA_HOME="$OUTILS/jdk"
export ANDROID_HOME="$OUTILS/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"

VERSION=$(cd "$PROJET" && node -p "require('./app/package.json').version")
VCODE=$(cd "$PROJET" && node -p "const [a,b,c]=require('./app/package.json').version.split('.').map(Number); a*10000+b*100+c")
echo "Version : $VERSION  (versionCode Android : $VCODE)"

ARCHIVE="$PROJET/dist/releases/$VERSION"
mkdir -p "$ARCHIVE" "$PROJET/dist"

if [ -f "$ARCHIVE/AFRAH-COMPTA-Windows-$VERSION.exe" ] || [ -f "$ARCHIVE/AFRAH-COMPTA-Android-$VERSION.apk" ]; then
  echo "!! ATTENTION : la version $VERSION existe deja dans dist/releases/$VERSION"
  echo "!! Augmentez le numero de version dans app/package.json avant de reconstruire,"
  echo "!! sinon l'archive de cette version serait ecrasee."
  read -p "Continuer quand meme et ecraser cette archive ? (o/N) " REPONSE
  [ "$REPONSE" = "o" ] || [ "$REPONSE" = "O" ] || { echo "Construction annulee."; exit 1; }
fi

# la copie "derniere version" dans dist/ ne garde qu'un exemplaire de chaque
# plateforme : on retire les anciens avant de copier les nouveaux
nettoyer_dist_courant() { rm -f "$PROJET/dist/AFRAH-COMPTA-Windows-"*.exe "$PROJET/dist/AFRAH-COMPTA-Android-"*.apk; }

journaliser() {
  local ligne="$1"
  echo "$(date '+%Y-%m-%d %H:%M')  $ligne" >> "$PROJET/dist/releases/journal.txt"
}

construire_windows() {
  echo "== Windows =="
  cd "$PROJET/app"
  CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --win nsis --x64 \
    --config.win.signAndEditExecutable=false --publish never
  cp "$PROJET/app/release/AFRAH COMPTA Setup $VERSION.exe" \
     "$ARCHIVE/AFRAH-COMPTA-Windows-$VERSION.exe"
  nettoyer_dist_courant_windows
  cp "$ARCHIVE/AFRAH-COMPTA-Windows-$VERSION.exe" "$PROJET/dist/"
  journaliser "Windows $VERSION -> dist/releases/$VERSION/"
  echo "-> dist/releases/$VERSION/AFRAH-COMPTA-Windows-$VERSION.exe  (archive permanente)"
  echo "-> dist/AFRAH-COMPTA-Windows-$VERSION.exe  (copie courante)"
}
nettoyer_dist_courant_windows() { rm -f "$PROJET/dist/AFRAH-COMPTA-Windows-"*.exe; }
nettoyer_dist_courant_android() { rm -f "$PROJET/dist/AFRAH-COMPTA-Android-"*.apk; }

construire_android() {
  echo "== Android =="
  rm -rf "$OUTILS/mobile/www"
  cp -r "$PROJET/app/www" "$OUTILS/mobile/www"
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
  cp app/build/outputs/apk/debug/app-debug.apk "$ARCHIVE/AFRAH-COMPTA-Android-$VERSION.apk"
  EMPREINTE=$("$ANDROID_HOME/build-tools/35.0.0/apksigner.bat" verify --print-certs \
    "$ARCHIVE/AFRAH-COMPTA-Android-$VERSION.apk" 2>/dev/null | grep -o "CN=AFRAH COMPTA" | head -1)
  if [ "$EMPREINTE" != "CN=AFRAH COMPTA" ]; then
    echo "!! ATTENTION : l'APK n'est PAS signe avec la cle permanente."
    echo "!! Les mises a jour seraient refusees par Android. Build interrompu."
    rm -f "$ARCHIVE/AFRAH-COMPTA-Android-$VERSION.apk"
    exit 1
  fi
  nettoyer_dist_courant_android
  cp "$ARCHIVE/AFRAH-COMPTA-Android-$VERSION.apk" "$PROJET/dist/"
  journaliser "Android $VERSION -> dist/releases/$VERSION/  (cle permanente OK)"
  echo "-> dist/releases/$VERSION/AFRAH-COMPTA-Android-$VERSION.apk  (archive permanente, signee)"
  echo "-> dist/AFRAH-COMPTA-Android-$VERSION.apk  (copie courante)"
}

case "${1:-tout}" in
  windows) construire_windows ;;
  android) construire_android ;;
  tout)    construire_windows; construire_android ;;
  *) echo "Usage : ./build.sh [windows|android|tout]"; exit 1 ;;
esac
echo "Termine."
echo "Historique complet des versions : dist/releases/"
echo "Derniere version (envoi rapide) : dist/"
