@echo off
rem Remove o Trabalhei instalado por install.cmd (chamado por "Aplicativos
rem instalados" no Windows).
setlocal
set "DEST=%LOCALAPPDATA%\Programs\Trabalhei"

taskkill /im Trabalhei.exe /f >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Trabalhei.lnk" >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Trabalhei" /f >nul 2>&1
rem A pasta e apagada depois que este script termina (ele esta dentro dela).
start "" /b cmd /c "timeout /t 2 /nobreak >nul & rmdir /s /q "%DEST%""
