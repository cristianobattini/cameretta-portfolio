@echo off
rem ============================================================
rem  CRI's CAMERETTA - riavvia il server su Windows
rem  Doppio clic: chiede i permessi di amministratore, riavvia
rem  il servizio "Cameretta" (e Caddy, se e' installato come
rem  servizio), poi controlla che il sito risponda.
rem ============================================================
setlocal
chcp 65001 >nul

rem --- serve l'amministratore: se non lo siamo, ci rilanciamo elevati
net session >nul 2>&1
if errorlevel 1 (
  echo Chiedo i permessi di amministratore...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

cd /d "%~dp0"
set "SERVIZIO=Cameretta"
set "NSSM=C:\nssm\win64\nssm.exe"
if not exist "%NSSM%" set "NSSM=nssm"
if "%CAMERETTA_PORT%"=="" set "CAMERETTA_PORT=8000"

echo.
echo === Riavvio del servizio %SERVIZIO% ===
sc query "%SERVIZIO%" >nul 2>&1
if errorlevel 1 (
  echo Il servizio "%SERVIZIO%" non esiste. Va prima creato con NSSM ^(vedi README^).
  goto fine
)
"%NSSM%" restart "%SERVIZIO%" >nul 2>&1
if errorlevel 1 (
  rem nssm non trovato o servizio fermo: si usa sc
  sc stop "%SERVIZIO%" >nul 2>&1
  timeout /t 3 /nobreak >nul
  sc start "%SERVIZIO%" >nul 2>&1
)

rem --- Caddy (solo se e' installato come servizio con questo nome)
sc query caddy >nul 2>&1
if not errorlevel 1 (
  echo === Riavvio di Caddy ===
  "%NSSM%" restart caddy >nul 2>&1 || (sc stop caddy >nul 2>&1 & timeout /t 2 /nobreak >nul & sc start caddy >nul 2>&1)
)

echo.
echo Attendo che il server risponda...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$u = 'http://127.0.0.1:' + $env:CAMERETTA_PORT + '/api/public'; for ($i = 0; $i -lt 20; $i++) { try { $r = Invoke-RestMethod -Uri $u -TimeoutSec 3; Write-Host ''; Write-Host ('OK: il server risponde. Sito: ' + $r.settings.site_name + ' - ' + @($r.sections).Count + ' sezioni') -ForegroundColor Green; exit 0 } catch { Start-Sleep -Seconds 1 } }; Write-Host ''; Write-Host 'Il server NON risponde dopo 20 secondi.' -ForegroundColor Red; exit 1"
if errorlevel 1 (
  echo.
  echo Stato del servizio:
  sc query "%SERVIZIO%" | findstr /i "STATE"
  echo.
  echo Ultime righe dei log ^(se ci sono^):
  for %%F in ("%~dp0service.log" "%~dp0data\service.log" "%~dp0service.err.log" "%~dp0data\service.err.log") do (
    if exist %%F (
      echo --- %%~F
      powershell -NoProfile -Command "Get-Content -LiteralPath '%%~F' -Tail 15"
    )
  )
  echo.
  echo Se lo stato e' PAUSED: il Python del servizio non va ^(ricrea il .venv con il Python di python.org^).
)

:fine
echo.
pause
