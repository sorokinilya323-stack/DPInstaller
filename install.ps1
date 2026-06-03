# ==========================
# DP Installer
# ==========================

$ErrorActionPreference = "Stop"

$dp = "C:\DP"

if (!(Test-Path $dp)) {
    New-Item -ItemType Directory -Path $dp | Out-Null
}

function Get-File {
    param(
        [string]$Url,
        [string]$Output
    )

    Write-Host ""
    Write-Host "Скачивание: $Output"
    Invoke-WebRequest -Uri $Url -OutFile $Output
}

Write-Host "Создана папка $dp"

# --------------------------------
# Everything (Тихая установка)
# --------------------------------

$everything = "$dp\Everything.exe"

Get-File `
"https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe" `
$everything

Write-Host "Установка Everything..."
Start-Process $everything -ArgumentList "/S" -Wait

# --------------------------------
# Windhawk (Тихая установка)
# --------------------------------

$windhawk = "$dp\WindhawkSetup.exe"

Get-File `
"https://github.com/ramensoftware/windhawk/releases/latest/download/windhawk_setup.exe" `
$windhawk

Write-Host "Установка Windhawk..."
Start-Process $windhawk -ArgumentList "/S /STANDARD" -Wait

# --------------------------------
# FreeSM Launcher (Обычная)
# --------------------------------

$freesm = "$dp\FreesmLauncher.exe"

Get-File `
"https://github.com/FreesmTeam/FreesmLauncher/releases/download/2.2.0/FreesmLauncher-Windows-MSVC-Setup-2.2.0.exe" `
$freesm

Write-Host "Запуск установки FreeSM Launcher..."
Start-Process $freesm -Wait

# --------------------------------
# Hiddify (Обычная)
# --------------------------------

$hiddify = "$dp\Hiddify.exe"

Get-File `
"https://github.com/hiddify/hiddify-app/releases/latest/download/Hiddify-Windows-Setup-x64.exe" `
$hiddify

Write-Host "Запуск установки Hiddify..."
Start-Process $hiddify -Wait

# --------------------------------
# MiniBin
# --------------------------------

$miniZip = "$dp\MiniBin.zip"
$miniDir = "$dp\MiniBin"

Get-File `
"https://e-sushi.net/wp-content/uploads/2012/03/MiniBin.zip" `
$miniZip

if (Test-Path $miniDir) {
    Remove-Item $miniDir -Recurse -Force
}

Expand-Archive $miniZip -DestinationPath $miniDir -Force

$miniExe = Get-ChildItem $miniDir -Filter "*.exe" -Recurse | Select-Object -First 1

if ($miniExe) {
    Write-Host "Запуск MiniBin..."
    Start-Process $miniExe.FullName
}

Write-Host ""
Write-Host "====================================="
Write-Host "Установка завершена."
Write-Host "Файлы находятся в $dp"
Write-Host "====================================="
