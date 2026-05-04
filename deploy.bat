@echo off
REM ============================================================
REM  Obstetrica 部署快捷啟動器（雙擊執行）
REM ============================================================
chcp 65001 > nul
cd /d "%~dp0"
echo.
echo  啟動 Obstetrica 自動部署...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
echo.
echo  按任意鍵關閉視窗...
pause > nul
