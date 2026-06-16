<#
.SYNOPSIS
    Автоматическая установка программ на чистую Windows 10/11
.DESCRIPTION
    Устанавливает приложения через winget и прямые загрузки с GitHub (FreeSMLauncher, MiniBin).
    Пропускает уже установленные программы.
#>

#region Массивы для логирования
$successList = [System.Collections.ArrayList]::new()
$alreadyList = [System.Collections.ArrayList]::new()
$failedList  = [System.Collections.ArrayList]::new()

#region Winget пакеты (id из официального репозитория)
$wingetPackages = @(
    @{ Id = "RamenSoftware.Windhawk";        Name = "Windhawk" },
    @{ Id = "voidtools.Everything";          Name = "Everything" },
    @{ Id = "AntibodySoftware.WizTree";      Name = "WizTree" },
    @{ Id = "Valve.Steam";                   Name = "Steam" },
    @{ Id = "Microsoft.VisualStudioCode";    Name = "Visual Studio Code" },
    @{ Id = "hiddify.hiddify";               Name = "Hiddify" },
    @{ Id = "qBittorrent.qBittorrent";       Name = "qBittorrent" },
    @{ Id = "Microsoft.PowerToys";           Name = "PowerToys" },
    @{ Id = "zhongyang219.TrafficMonitor";   Name = "TrafficMonitor" },
    @{ Id = "Dev47Apps.DroidCam";            Name = "DroidCam" },
    @{ Id = "LocalSend.LocalSend";           Name = "LocalSend" },
    @{ Id = "Discord.Discord";               Name = "Discord" }
)

#region GitHub-репозитории для fallback установки
$githubApps = @(
    @{ 
        Owner = "FreesmTeam"
        Repo = "FreesmLauncher"
        Name = "FreeSM Launcher"
        ExePattern = "\.exe$"
        SilentArgs = @("/S", "/SILENT")
        CheckPaths = @(
            "$env:LOCALAPPDATA\Programs\FreeSM Launcher\FreeSM Launcher.exe"
        )
    }
    @{ 
        Owner = "kobaltgit"
        Repo = "MiniBin"
        Name = "MiniBin"
        ExePattern = "\.exe$"
        SilentArgs = @("/S", "/SILENT")
        CheckPaths = @(
            "$env:ProgramFiles\MiniBin\MiniBin.exe",
            "$env:LOCALAPPDATA\MiniBin\MiniBin.exe"
        )
    }
)

#region Вспомогательные функции
function Test-WingetInstalled {
    param([string]$packageId)
    try {
        $result = & winget list --exact --id $packageId --disable-interactivity 2>&1
        if ($LASTEXITCODE -eq 0 -and ($result -match $packageId)) {
            return $true
        }
    } catch { }
    return $false
}

function Test-GitHubAppInstalled {
    param([string[]]$checkPaths)
    foreach ($path in $checkPaths) {
        if (Test-Path $path -PathType Leaf) {
            return $true
        }
    }
    # Дополнительно проверим по имени процесса
    $procName = (Split-Path $checkPaths[0] -LeafBase)
    if (Get-Process $procName -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Test-Winget {
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        return $true
    }
    Write-Warning "winget не найден. Попытка инициализации через Microsoft Store..."
    try {
        Start-Process "ms-windows-store://pdp/?ProductId=9nblggh4nns1" -ErrorAction Stop
        Write-Host "Открыт Microsoft Store. Пожалуйста, установите 'App Installer' и перезапустите скрипт." -ForegroundColor Yellow
        pause
        if (Get-Command "winget" -ErrorAction SilentlyContinue) {
            return $true
        } else {
            throw "winget так и не появился"
        }
    }
    catch {
        Write-Error "Не удалось инициализировать winget. Установите 'App Installer' вручную из Store."
        return $false
    }
}

function Install-WithWinget {
    param($packageId, $displayName)
    # Проверка, установлена ли уже
    if (Test-WingetInstalled -packageId $packageId) {
        Write-Host "⏭️  $displayName уже установлен (пропуск)" -ForegroundColor Gray
        $alreadyList.Add("$displayName ($packageId)") | Out-Null
        return
    }
    
    Write-Host "📦 Установка $displayName через winget..."
    try {
        & winget install --id $packageId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $displayName установлен" -ForegroundColor Green
            $successList.Add("$displayName ($packageId)") | Out-Null
        } else {
            throw "winget завершился с кодом $LASTEXITCODE"
        }
    }
    catch {
        Write-Warning "❌ Ошибка установки $displayName : $_"
        $failedList.Add("$displayName ($packageId)") | Out-Null
    }
}

function Install-FromGitHub {
    param($owner, $repo, $displayName, $silentArgs, $checkPaths)
    # Проверка, установлена ли уже
    if (Test-GitHubAppInstalled -checkPaths $checkPaths) {
        Write-Host "⏭️  $displayName уже установлен (пропуск)" -ForegroundColor Gray
        $alreadyList.Add($displayName) | Out-Null
        return
    }

    $tempDir = $env:TEMP
    $apiUrl = "https://api.github.com/repos/$owner/$repo/releases/latest"
    try {
        Write-Host "🌐 Получение информации о последнем релизе $displayName ..."
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match "\.exe$" } | Select-Object -First 1
        if (-not $asset) {
            throw "Не найден .exe файл в релизе"
        }
        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $localPath = Join-Path $tempDir $fileName

        Write-Host "⬇️  Скачивание $fileName ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localPath -ErrorAction Stop

        $installed = $false
        foreach ($arg in $silentArgs) {
            Write-Host "🔧 Запуск $fileName с параметром $arg ..."
            $process = Start-Process -FilePath $localPath -ArgumentList $arg -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                $installed = $true
                break
            } else {
                Write-Warning "Не удалось установить с $arg (код $($process.ExitCode))"
            }
        }
        if ($installed) {
            Write-Host "✅ $displayName установлен" -ForegroundColor Green
            $successList.Add($displayName) | Out-Null
        } else {
            throw "Ни один из тихих аргументов не сработал"
        }
        Remove-Item $localPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "❌ Ошибка при установке $displayName : $_"
        $failedList.Add($displayName) | Out-Null
    }
}

#region Основной процесс
Clear-Host
Write-Host "=== Начало автоматической установки ===" -ForegroundColor Cyan

# 1. Инициализация winget
if (-not (Test-Winget)) {
    Write-Error "Невозможно продолжить: winget не доступен."
    exit 1
}

# 2. Установка пакетов через winget
foreach ($pkg in $wingetPackages) {
    Install-WithWinget -packageId $pkg.Id -displayName $pkg.Name
}

# 3. Установка приложений через GitHub
foreach ($app in $githubApps) {
    Install-FromGitHub -owner $app.Owner -repo $app.Repo -displayName $app.Name -silentArgs $app.SilentArgs -checkPaths $app.CheckPaths
}

#region Вывод результатов
Clear-Host
Write-Host "==================== РЕЗУЛЬТАТ УСТАНОВКИ ====================" -ForegroundColor Cyan

Write-Host "`n🟢 УСПЕШНО УСТАНОВЛЕНО:" -ForegroundColor Green
if ($successList.Count -eq 0) {
    Write-Host "  (нет)" -ForegroundColor Gray
} else {
    foreach ($item in $successList) {
        Write-Host "  ✓ $item" -ForegroundColor Green
    }
}

Write-Host "`n🟡 УЖЕ УСТАНОВЛЕНЫ (пропущены):" -ForegroundColor Yellow
if ($alreadyList.Count -eq 0) {
    Write-Host "  (нет)" -ForegroundColor Gray
} else {
    foreach ($item in $alreadyList) {
        Write-Host "  • $item" -ForegroundColor Yellow
    }
}

Write-Host "`n🔴 НЕ УДАЛОСЬ УСТАНОВИТЬ:" -ForegroundColor Red
if ($failedList.Count -eq 0) {
    Write-Host "  (нет)" -ForegroundColor Gray
} else {
    foreach ($item in $failedList) {
        Write-Host "  ✗ $item" -ForegroundColor Red
    }
}
Write-Host "`n=============================================================" -ForegroundColor Cyan
#endregion
