@echo off
rem Sviluppo: apre il sito in Chrome e lo aggiorna a ogni modifica del codice
cd /d "%~dp0"
call C:\Users\Utente\flutter\bin\dart.bat run tool\live.dart
