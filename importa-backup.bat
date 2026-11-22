@echo off
rem ============================================================
rem  CRI's CAMERETTA - importa un backup nel sito
rem  Uso: trascina un file .json sopra questo .bat
rem       (backup "Esporta tutto", data.json oppure contenuti.json).
rem  Senza file usa contenuti.json (progetti, elaborati, appunti,
rem  libri, percorso e bolle come nella versione originale).
rem  Va lanciato sul server, con il servizio Cameretta acceso.
rem  Prima di importare il server salva una copia del database
rem  in data\backup-DATA-ORA.db
rem ============================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"
set "FILE=%~1"
if "%FILE%"=="" set "FILE=%~dp0contenuti.json"
if not exist "%FILE%" (
  echo File non trovato: "%FILE%"
  goto fine
)
if "%CAMERETTA_PORT%"=="" set "CAMERETTA_PORT=8000"
echo File: "%FILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $raw = Get-Content -LiteralPath $env:FILE -Raw -Encoding UTF8; $bk = $raw | ConvertFrom-Json; $nS = @($bk.sections).Count; $nB = @($bk.bubbles).Count; $nI = if ($bk.items) { @($bk.items).Count } else { (@($bk.sections) | ForEach-Object { @($_.items).Count } | Measure-Object -Sum).Sum }; $nK = if ($bk.settings) { @($bk.settings.PSObject.Properties).Count } else { 0 }; Write-Host ''; Write-Host ('Nel file: ' + $nK + ' impostazioni, ' + $nS + ' sezioni, ' + $nI + ' voci, ' + $nB + ' bolle') -ForegroundColor Cyan; Write-Host ''; Write-Host '  1 = importa TUTTO (sezioni, voci e bolle attuali vengono sostituite)'; Write-Host '  2 = solo le impostazioni'; Write-Host '  0 = annulla'; $c = Read-Host 'Scelta'; if ($c -eq '1') { $payload = $raw } elseif ($c -eq '2') { $payload = (@{ settings = $bk.settings } | ConvertTo-Json -Depth 6) } else { Write-Host 'Annullato.'; exit 1 }; $sec = Read-Host 'Password admin (Invio se non l''hai impostata)' -AsSecureString; $tok = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)); $h = @{}; if ($tok) { $h['X-Admin-Token'] = $tok }; $url = 'http://127.0.0.1:' + $env:CAMERETTA_PORT + '/api/import'; $r = Invoke-RestMethod -Method Post -Uri $url -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)); Write-Host ''; Write-Host ('Fatto! Importati: ' + ($r.imported | ConvertTo-Json -Compress)) -ForegroundColor Green; Write-Host ('Copia del database di prima: data\' + $r.backup); Write-Host 'Ricarica la pagina del gioco.' } catch { Write-Host ''; $m = $_.Exception.Message; if ($m -match '401') { $m = 'Password admin sbagliata.' } elseif ($m -match '404') { $m = 'Il server non conosce /api/import: aggiorna server.py e riavvia il servizio (nssm restart Cameretta).' } elseif ($m -match 'connect|connessione|refused|rifiutat') { $m = 'Il server non risponde: il servizio Cameretta e'' acceso?' }; Write-Host ('Errore: ' + $m) -ForegroundColor Red; exit 1 }"

:fine
echo.
pause
