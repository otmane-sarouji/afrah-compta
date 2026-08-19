@echo off
REM ===========================================================================
REM  AFRAH COMPTA — ouvre le telephone virtuel et y installe la derniere version
REM  Double-cliquez simplement sur ce fichier.
REM ===========================================================================
setlocal
set OUTILS=C:\Users\Henry\afrah-build
set SDK=%OUTILS%\android-sdk
set ADB=%SDK%\platform-tools\adb.exe
set PROJET=%~dp0

echo.
echo == Demarrage du telephone virtuel (patientez, la premiere fois est longue) ==
start "Telephone virtuel AFRAH" "%SDK%\emulator\emulator.exe" -avd afrah-telephone -no-snapshot-load

echo.
echo == Attente du demarrage d'Android ==
"%ADB%" wait-for-device
:attendre
for /f "tokens=*" %%i in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
if not "%BOOT%"=="1" (
  timeout /t 3 /nobreak >nul
  goto attendre
)
echo Android est pret.

echo.
echo == Installation de la derniere version de l'application ==
for /f "delims=" %%f in ('dir /b /o-n "%PROJET%dist\AFRAH-COMPTA-Android-*.apk"') do set APK=%%f
echo Fichier : %APK%
"%ADB%" install -r "%PROJET%dist\%APK%"

echo.
echo == Ouverture de l'application ==
"%ADB%" shell monkey -p ma.afrah.compta -c android.intent.category.LAUNCHER 1 >nul 2>&1

echo.
echo Termine. L'application est ouverte dans la fenetre du telephone virtuel.
echo Laissez cette fenetre ouverte ou fermez-la, cela n'a pas d'importance.
pause
