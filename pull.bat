@echo off
cd /d "%~dp0"

echo === git fetch ===
git fetch --all --prune
if errorlevel 1 goto :error

echo === git pull --rebase ===
git pull --rebase
if errorlevel 1 goto :error

echo.
echo Aggiornamento completato.
pause
exit /b 0

:error
echo.
echo ERRORE: aggiornamento non riuscito. Controlla i messaggi sopra.
echo Se il rebase e' in corso con conflitti, risolvili oppure usa "git rebase --abort".
pause
exit /b 1
