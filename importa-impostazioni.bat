@echo off
rem ============================================================
rem  La cameretta - importa le impostazioni da un backup JSON
rem  Uso: trascina il file di backup sopra questo .bat
rem       (oppure avvialo e incolla il percorso quando lo chiede).
rem  Va lanciato sul server, con il servizio Cameretta acceso.
rem ============================================================
setlocal
chcp 65001 >nul
set "FILE=%~1"
if "%FILE%"=="" set /p "FILE=Percorso del file di backup (.json): "
set "FILE=%FILE:"=%"
if not exist "%FILE%" (
  echo.
  echo File non trovato: %FILE%
  goto fine
)
if "%CAMERETTA_PORT%"=="" set "CAMERETTA_PORT=8000"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $bk = Get-Content -LiteralPath $env:FILE -Raw -Encoding UTF8 | ConvertFrom-Json; if (-not $bk.settings) { throw 'Nel file non c''e'' la parte settings: e'' il backup giusto?' }; $keys = @($bk.settings.PSObject.Properties.Name); Write-Host ''; Write-Host ('Trovate ' + $keys.Count + ' impostazioni:') -ForegroundColor Cyan; Write-Host ('  ' + ($keys -join ', ')); Write-Host ''; $ok = Read-Host 'Le importo? Quelle con lo stesso nome verranno sovrascritte (s/n)'; if ($ok -notmatch '^[sSyY]') { Write-Host 'Annullato.'; exit 1 }; $sec = Read-Host 'Password admin (Invio se non l''hai impostata)' -AsSecureString; $tok = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)); $h = @{}; if ($tok) { $h['X-Admin-Token'] = $tok }; $body = [Text.Encoding]::UTF8.GetBytes(($bk.settings | ConvertTo-Json -Depth 5)); $url = 'http://127.0.0.1:' + $env:CAMERETTA_PORT + '/api/settings'; Invoke-RestMethod -Method Put -Uri $url -Headers $h -ContentType 'application/json; charset=utf-8' -Body $body | Out-Null; Write-Host ''; Write-Host 'Fatto: impostazioni importate. Ricarica la pagina del gioco.' -ForegroundColor Green } catch { Write-Host ''; $m = $_.Exception.Message; if ($m -match '401') { $m = 'Password admin sbagliata.' } elseif ($m -match 'connect|connessione|refused|rifiutat') { $m = 'Il server non risponde: il servizio Cameretta e'' acceso? (nssm start Cameretta)' }; Write-Host ('Errore: ' + $m) -ForegroundColor Red; exit 1 }"

:fine
echo.
pause
