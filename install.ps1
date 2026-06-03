# ==========================
# DP Installer
# ==========================
 
#Requires -RunAsAdministrator
 
$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
 
$dp = "C:\DP"
New-Item -ItemType Directory -Path $dp -Force | Out-Null
Write-Host "Создана папка $dp"
 
# -------------------------------------------------------
# Вспомогательные функции
# -------------------------------------------------------
 
function Get-File {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
 
        [Parameter(Mandatory)]
        [string]$Output
    )
 
    Write-Host ""
    Write-Host "Скачивание: $(Split-Path $Output -Leaf)"
 
    if (Test-Path $Output) {
        Remove-Item $Output -Force
    }
 
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & curl.exe -L --fail --silent --show-error --retry 3 --retry-delay 2 --output $Output $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl не смог скачать файл: $Url"
        }
    }
    else {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Output -MaximumRedirection 10 -UseBasicParsing
        }
        catch {
            throw "Invoke-WebRequest не смог скачать файл: $Url`nОшибка: $_"
        }
    }
 
    if (!(Test-Path $Output) -or (Get-Item $Output).Length -eq 0) {
        throw "Файл не был создан или пустой: $Output"
    }
}
 
function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
 
        [Parameter(Mandatory)]
        [string]$Repo,
 
        [Parameter(Mandatory)]
        [string]$AssetPattern
    )
 
    $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    $headers = @{
        "User-Agent" = "DPInstaller/1.0"
        "Accept"     = "application/vnd.github+json"
    }
 
    try {
        $release = Invoke-RestMethod -Uri $api -Headers $headers
    }
    catch {
        throw "Не удалось получить данные релиза $Owner/$Repo : $_"
    }
 
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
 
    if (-not $asset) {
        $available = ($release.assets | Select-Object -ExpandProperty name) -join ", "
        throw "Не найден файл по шаблону '$AssetPattern' в $Owner/$Repo.`nДоступные файлы: $available"
    }
 
    return $asset.browser_download_url
}
 
function Install-Exe {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
 
        [string[]]$Arguments = @()
    )
 
    if (-not (Test-Path $Path)) {
        throw "Установщик не найден: $Path"
    }
 
    $params = @{
        FilePath = $Path
        Wait     = $true
        PassThru = $true
    }
 
    if ($Arguments.Count -gt 0) {
        $params.ArgumentList = $Arguments
    }
 
    $process = Start-Process @params
 
    # Код 0 — успех, 3010 — успех с перезагрузкой
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Установщик '$Path' завершился с ошибкой. Код: $($process.ExitCode)"
    }
 
    if ($process.ExitCode -eq 3010) {
        Write-Host "  [!] Требуется перезагрузка для завершения установки."
    }
}
 
# -------------------------------------------------------
# Everything — через winget
# Парсинг HTML страницы ненадёжен: Voidtools меняют вёрстку.
# winget всегда даёт актуальную версию из официального источника.
# -------------------------------------------------------
 
Write-Host ""
Write-Host "--- Everything ---"
 
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget не найден. Установи 'App Installer' из Microsoft Store."
}
 
Write-Host "Установка Everything через winget..."
& winget install --id voidtools.Everything --silent --accept-package-agreements --accept-source-agreements
 
if ($LASTEXITCODE -notin @(0, 3010)) {
    throw "winget не смог установить Everything. Код: $LASTEXITCODE"
}
 
# -------------------------------------------------------
# Windhawk
# -------------------------------------------------------
 
Write-Host ""
Write-Host "--- Windhawk ---"
 
$windhawkUrl = Get-GitHubLatestAssetUrl `
    -Owner "ramensoftware" `
    -Repo "windhawk" `
    -AssetPattern "windhawk_setup\.exe$"
 
$windhawk = Join-Path $dp "WindhawkSetup.exe"
 
Get-File -Url $windhawkUrl -Output $windhawk
 
Write-Host "Установка Windhawk..."
Install-Exe -Path $windhawk -Arguments @("/S", "/STANDARD")
 
# -------------------------------------------------------
# FreeSM Launcher
# -------------------------------------------------------
 
Write-Host ""
Write-Host "--- FreeSM Launcher ---"
 
$freesmUrl = Get-GitHubLatestAssetUrl `
    -Owner "FreesmTeam" `
    -Repo "FreesmLauncher" `
    -AssetPattern "Setup.*\.exe$"
 
$freesm = Join-Path $dp "FreesmLauncher.exe"
 
Get-File -Url $freesmUrl -Output $freesm
 
Write-Host "Запуск установки FreeSM Launcher..."
Install-Exe -Path $freesm
 
# -------------------------------------------------------
# Hiddify
# -------------------------------------------------------
 
Write-Host ""
Write-Host "--- Hiddify ---"
 
$hiddifyUrl = Get-GitHubLatestAssetUrl `
    -Owner "hiddify" `
    -Repo "hiddify-app" `
    -AssetPattern "Windows.*Setup.*x64.*\.exe$"
 
$hiddify = Join-Path $dp "Hiddify.exe"
 
Get-File -Url $hiddifyUrl -Output $hiddify
 
Write-Host "Запуск установки Hiddify..."
Install-Exe -Path $hiddify
 
# -------------------------------------------------------
# MiniBin
# -------------------------------------------------------
 
Write-Host ""
Write-Host "--- MiniBin ---"
 
$miniZip = Join-Path $dp "MiniBin.zip"
$miniDir = Join-Path $dp "MiniBin"
 
Get-File -Url "https://e-sushi.net/wp-content/uploads/2012/03/MiniBin.zip" -Output $miniZip
 
if (Test-Path $miniDir) {
    Remove-Item $miniDir -Recurse -Force
}
 
Expand-Archive -Path $miniZip -DestinationPath $miniDir -Force
 
$miniExe = Get-ChildItem -Path $miniDir -Filter "*.exe" -Recurse | Select-Object -First 1
 
if (-not $miniExe) {
    Write-Warning "MiniBin: .exe не найден в архиве. Проверьте содержимое $miniDir"
}
else {
    Write-Host "Запуск MiniBin..."
    Start-Process -FilePath $miniExe.FullName
}
 
# -------------------------------------------------------
# Готово
# -------------------------------------------------------
 
Write-Host ""
Write-Host "====================================="
Write-Host " Установка завершена."
Write-Host " Файлы находятся в $dp"
Write-Host "====================================="
