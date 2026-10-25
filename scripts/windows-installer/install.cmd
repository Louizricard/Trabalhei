@echo off
rem Instala o Trabalhei na conta do usuario (sem pedir administrador):
rem copia o app, cria o atalho no menu Iniciar e registra a desinstalacao.
setlocal
set "DEST=%LOCALAPPDATA%\Programs\Trabalhei"
set "VERSION=__VERSION__"
set "UNINSTALL_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Trabalhei"

taskkill /im Trabalhei.exe /f >nul 2>&1
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%" || exit /b 1
tar -xf "%~dp0app.zip" -C "%DEST%" || exit /b 1
copy /y "%~dp0uninstall.cmd" "%DEST%\uninstall.cmd" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Programs') + '\Trabalhei.lnk'); $s.TargetPath = '%DEST%\Trabalhei.exe'; $s.WorkingDirectory = '%DEST%'; $s.Save()"

reg add "%UNINSTALL_KEY%" /v DisplayName /d "Trabalhei" /f >nul
reg add "%UNINSTALL_KEY%" /v DisplayVersion /d "%VERSION%" /f >nul
reg add "%UNINSTALL_KEY%" /v Publisher /d "LouizVolution" /f >nul
reg add "%UNINSTALL_KEY%" /v DisplayIcon /d "%DEST%\Trabalhei.exe" /f >nul
reg add "%UNINSTALL_KEY%" /v InstallLocation /d "%DEST%" /f >nul
reg add "%UNINSTALL_KEY%" /v UninstallString /d "\"%DEST%\uninstall.cmd\"" /f >nul
reg add "%UNINSTALL_KEY%" /v NoModify /t REG_DWORD /d 1 /f >nul
reg add "%UNINSTALL_KEY%" /v NoRepair /t REG_DWORD /d 1 /f >nul

rem Abre pelo Explorer para o instalador nao ficar esperando o app fechar.
explorer.exe "%DEST%\Trabalhei.exe"
exit /b 0
