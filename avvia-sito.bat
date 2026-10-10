@echo off
rem Apre il sito offline nel browser (http://localhost:8282)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\server_locale.ps1" -Porta 8282
