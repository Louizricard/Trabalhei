# Gera o ZIP portátil e o instalador .exe do Windows a partir do build release.
# O instalador é montado pelo IExpress, que já vem no Windows (sem ferramentas
# extras): extrai o app em %LOCALAPPDATA%\Programs\Trabalhei, cria o atalho no
# menu Iniciar e registra a desinstalação em "Aplicativos instalados".
#
# Uso, na raiz do repositório, depois de `flutter build windows --release`:
#   powershell -ExecutionPolicy Bypass -File scripts\windows-installer\build.ps1
param([string]$OutDir = 'release')
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$version = (Select-String -Path "$root\freelanceflow\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
$build = "$root\freelanceflow\build\windows\x64\runner\Release"
if (-not (Test-Path "$build\Trabalhei.exe")) { throw 'Rode antes: flutter build windows --release' }

$out = (New-Item -ItemType Directory -Force (Join-Path $root $OutDir)).FullName
$stage = Join-Path ([IO.Path]::GetTempPath()) "trabalhei-windows-$version"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory "$stage\Trabalhei", "$stage\pkg" | Out-Null
Copy-Item "$build\*" "$stage\Trabalhei" -Recurse

# ZIP portátil: uma pasta Trabalhei com o executável. O tar do Windows grava os
# caminhos com "/", que qualquer descompactador entende.
$zip = Join-Path $out "trabalhei-$version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip }
tar -a -cf $zip -C $stage Trabalhei
if ($LASTEXITCODE) { throw 'Falha ao gerar o ZIP.' }

# Pacote do instalador: app.zip com os arquivos na raiz + scripts em CRLF.
Push-Location "$stage\Trabalhei"
tar -a -cf "$stage\pkg\app.zip" *
$tarExit = $LASTEXITCODE
Pop-Location
if ($tarExit) { throw 'Falha ao gerar o app.zip.' }
foreach ($name in 'install.cmd', 'uninstall.cmd') {
  $text = (Get-Content "$PSScriptRoot\$name" -Raw).Replace('__VERSION__', $version) -replace "`r?`n", "`r`n"
  [IO.File]::WriteAllText("$stage\pkg\$name", $text, [Text.Encoding]::ASCII)
}

$setup = Join-Path $out "trabalhei-$version-windows-x64-setup.exe"
# ".\install.cmd" com caminho: funciona mesmo com NoDefaultCurrentDirectoryInExePath ativo.
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=Instalar o Trabalhei $version?
DisplayLicense=
FinishMessage=Pronto! O Trabalhei foi instalado e está no menu Iniciar.
TargetName=$setup
FriendlyName=Trabalhei $version
AppLaunched=cmd /c .\install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=cmd /c .\install.cmd
UserQuietInstCmd=cmd /c .\install.cmd
FILE0="app.zip"
FILE1="install.cmd"
FILE2="uninstall.cmd"
[SourceFiles]
SourceFiles0=$stage\pkg\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@
# O IExpress lê o .sed na página de código do Windows (acentos inclusos).
[IO.File]::WriteAllText("$stage\trabalhei.sed", $sed, [Text.Encoding]::Default)
if (Test-Path $setup) { Remove-Item $setup }
Start-Process -FilePath "$env:WINDIR\System32\iexpress.exe" -ArgumentList '/N', '/Q', "$stage\trabalhei.sed" -Wait -NoNewWindow
if (-not (Test-Path $setup)) { throw 'O IExpress não gerou o instalador.' }

Remove-Item -Recurse -Force $stage
Get-Item $zip, $setup | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
