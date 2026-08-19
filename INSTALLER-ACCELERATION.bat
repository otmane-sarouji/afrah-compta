@echo off
REM ===========================================================================
REM  Installe le pilote d'acceleration de l'emulateur Android.
REM  A LANCER EN TANT QU'ADMINISTRATEUR (clic droit > Executer en tant
REM  qu'administrateur). Une seule fois, puis redemarrer le PC.
REM ===========================================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo  ERREUR : ce fichier doit etre lance en tant qu'administrateur.
  echo.
  echo  Fermez cette fenetre, faites un CLIC DROIT sur
  echo  INSTALLER-ACCELERATION.bat puis choisissez
  echo  "Executer en tant qu'administrateur".
  echo.
  pause
  exit /b 1
)
echo Installation du pilote d'acceleration...
cd /d "C:\Users\Henry\afrah-build\android-sdk\extras\google\Android_Emulator_Hypervisor_Driver"
call silent_install.bat
echo.
echo Termine. REDEMARREZ l'ordinateur pour que le pilote soit actif.
pause
