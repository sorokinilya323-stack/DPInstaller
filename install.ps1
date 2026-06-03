# ==========================
# DP Installer
# ==========================

$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$dp = "C:\DP"
New-Item -ItemType Directory -Path $dp -Force | Out-Null

function Get-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    Write-Host ""
    Write-Host "Скачивание: $Output"

    if (Test-Path $Output) {
        Remove-Item $Output -Force
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & curl.exe -L --fail --silent --show-error --retry 3 --retry-delay 2 --output $Output $Url
        if ($LASTEXITCODE -ne 0) {
            throw "Не удалось скачать файл: $Url"
        }
    }
    else {
        Invoke-WebRequest -Uri $Url -OutFile $Output -MaximumRedirection 10
    }

    if (!(Test-Path $Output)) {
        throw "Файл не был создан: $Output"
    }
}

function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo,

        [Parameter(Mandatory = $true)]
        [string]$AssetPattern
    )

    $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    $headers = @{
        "User-Agent" = "DPInstaller"
        "Accept"     = "application/vnd.github+json"
    }

    $release = Invoke-RestMethod -Uri $api -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw "Не найден файл релиза у $Owner/$Repo по шаблону: $AssetPattern"
    }

    return $asset.browser_download_url
}

function Get-VoidtoolsEverythingUrl {
    $headers = @{
        "User-Agent" = "DPInstaller"
    }

    $page = (Invoke-WebRequest -Uri "https://www.voidtools.com/downloads/" -Headers $headers).Content
    $match = [regex]::Match($page, 'https://www\.voidtools\.com/Everything-[^"''\s>]*x64-Setup\.exe')

    if (-not $match.Success) {
        throw "Не удалось найти ссылку для Everything."
    }

    return $match.Value
}

function Install-Exe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string[]]$Arguments = @()
    )

    if ($Arguments.Count -gt 0) {
        Start-Process -FilePath $Path -ArgumentList $Arguments -Wait
    }
    else {
        Start-Process -FilePath $Path -Wait
    }
}

Write-Host "Создана папка $dp"

# --------------------------------
# Everything (тихо)
# --------------------------------

$everything = Join-Path $dp "Everything.exe"
$everythingUrl = Get-VoidtoolsEverythingUrl

Get-File -Url $everythingUrl -Output $everything

Write-Host "Установка Everything..."
Install-Exe -Path $everything -Arguments @("/S")

# --------------------------------
# Windhawk (тихо)
# --------------------------------

$windhawk = Join-Path $dp "WindhawkSetup.exe"
$windhawkUrl = Get-GitHubLatestAssetUrl -Owner "ramensoftware" -Repo "windhawk" -AssetPattern "windhawk_setup\.exe$"

Get-File -Url $windhawkUrl -Output $windhawk

Write-Host "Установка Windhawk..."
Install-Exe -Path $windhawk -Arguments @("/S", "/STANDARD")

# --------------------------------
# FreeSM Launcher (обычная)
# --------------------------------

$freesm = Join-Path $dp "FreesmLauncher.exe"
$freesmUrl = Get-GitHubLatestAssetUrl -Owner "FreesmTeam" -Repo "FreesmLauncher" -AssetPattern "Setup.*\.exe$"

Get-File -Url $freesmUrl -Output $freesm

Write-Host "Запуск установки FreeSM Launcher..."
Install-Exe -Path $freesm

# --------------------------------
# Hiddify (обычная)
# --------------------------------

$hiddify = Join-Path $dp "Hiddify.exe"
$hiddifyUrl = Get-GitHubLatestAssetUrl -Owner "hiddify" -Repo "hiddify-app" -AssetPattern "Windows.*Setup.*x64.*\.exe$"

Get-File -Url $hiddifyUrl -Output $hiddify

Write-Host "Запуск установки Hiddify..."
Install-Exe -Path $hiddify

# --------------------------------
# MiniBin
# --------------------------------

$miniZip = Join-Path $dp "MiniBin.zip"
$miniDir = Join-Path $dp "MiniBin"

Get-File -Url "https://e-sushi.net/wp-content/uploads/2012/03/MiniBin.zip" -Output $miniZip

if (Test-Path $miniDir) {
    Remove-Item $miniDir -Recurse -Force
}

Expand-Archive -Path $miniZip -DestinationPath $miniDir -Force

$miniExe = Get-ChildItem -Path $miniDir -Filter "*.exe" -Recurse | Select-Object -First 1

if ($miniExe) {
    Write-Host "Запуск MiniBin..."
    Start-Process -FilePath $miniExe.FullName
}

Write-Host ""
Write-Host "====================================="
Write-Host "Установка завершена."
Write-Host "Файлы находятся в $dp"
Write-Host "====================================="
