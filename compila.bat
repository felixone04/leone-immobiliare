@echo off
rem Compila il sito per l'uso offline nella cartella sito_offline
cd /d "%~dp0"
call C:\Users\Utente\flutter\bin\flutter.bat build web --release --no-web-resources-cdn
if errorlevel 1 (
  echo Compilazione non riuscita
  pause
  exit /b 1
)
if exist sito_offline rmdir /s /q sito_offline
xcopy /e /i /q build\web sito_offline >nul
echo Fatto: ora puoi usare avvia-sito.bat
pause
