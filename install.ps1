# Ставит или обновляет всю сборку euf (NeoForge 1.21.1) в папку mods TLauncher:
# все моды из modpack.json, включая Photon и его библиотеки. Старые версии этих модов и моды прежней
# Fabric-сборки убирает.
# Запуск: двойной клик по install-modpack.bat (лежит рядом).
#   -Stable           брать стабильные релизы наших модов (v*), а не свежие dev-сборки
#   -VersionName "…"  имя версии NeoForge в TLauncher (по умолчанию ищется сама)
#   -GameDir "…"      папка игры (по умолчанию %APPDATA%\.minecraft)
param(
    [switch]$Stable,
    [string]$VersionName = '',
    [string]$GameDir = (Join-Path $env:APPDATA '.minecraft')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PackRepo = 'stardely62-oss/euf-modpack'
$Headers = @{ 'User-Agent' = 'euf-modpack-installer' }

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

# Свежий список модов из репозитория сборки; без интернета до GitHub — тот, что лежит рядом
function Get-Manifest {
    try {
        return Invoke-RestMethod "https://raw.githubusercontent.com/$PackRepo/main/modpack.json" -Headers $Headers
    } catch {
        $local = Join-Path $PSScriptRoot 'modpack.json'
        if (Test-Path -LiteralPath $local) { return Get-Content -LiteralPath $local -Raw -Encoding UTF8 | ConvertFrom-Json }
        throw "Не удалось получить список модов сборки."
    }
}

# Версия NeoForge из json версии TLauncher, или $null, если это не NeoForge 1.21.1
function Get-NeoForge($dir) {
    foreach ($json in Get-ChildItem -LiteralPath $dir -Filter '*.json' -ErrorAction SilentlyContinue) {
        $text = Get-Content -LiteralPath $json.FullName -Raw
        foreach ($pattern in @('net\.neoforged:neoforge:(21\.1\.[0-9]+)', 'fml\.neoForgeVersion"\s*,\s*"(21\.1\.[0-9]+)', 'neoforge-(21\.1\.[0-9]+)')) {
            $m = [regex]::Match($text, $pattern)
            if ($m.Success) { return [version]$m.Groups[1].Value }
        }
    }
    return $null
}

function Remove-Old($mods, $patterns, $keep) {
    foreach ($pattern in $patterns) {
        Get-ChildItem -LiteralPath $mods -Filter $pattern | Where-Object { $_.Name -ne $keep } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    }
}

try {
    Say "== Сборка euf: установка и обновление ==" Cyan

    $manifest = Get-Manifest

    # 1. Версия NeoForge 1.21.1 в TLauncher: названная или найденная сама
    $versionsDir = Join-Path $GameDir 'versions'
    if ($VersionName) {
        $versionDir = Join-Path $versionsDir $VersionName
        if (-not (Test-Path -LiteralPath $versionDir)) {
            throw "Не нашёл версию '$VersionName' в $versionsDir. Установи её в TLauncher и запусти один раз."
        }
        $neo = Get-NeoForge $versionDir
        if (-not $neo) { throw "Версия '$VersionName' не похожа на NeoForge 1.21.1." }
    } else {
        $found = @(Get-ChildItem -LiteralPath $versionsDir -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { $n = Get-NeoForge $_.FullName; if ($n) { [pscustomobject]@{ Dir = $_; Neo = $n } } } |
            Sort-Object Neo -Descending)
        if ($found.Count -eq 0) {
            throw "Не нашёл NeoForge 1.21.1 в $versionsDir. Установи в TLauncher версию NeoForge 1.21.1 и запусти её один раз."
        }
        $versionDir = $found[0].Dir.FullName
        $VersionName = $found[0].Dir.Name
        $neo = $found[0].Neo
    }
    Say "Версия: $VersionName (NeoForge $neo)"
    $min = [version]$manifest.neoforge_min
    if ($neo -lt $min) {
        throw "NeoForge $neo слишком старый, нужен $min или новее. Поставь в TLauncher NeoForge 1.21.1 поновее."
    }

    # 2. Папка mods: отдельная у версии, если TLauncher так настроен, иначе общая
    $mods = Join-Path $versionDir 'mods'
    if (-not (Test-Path -LiteralPath $mods)) { $mods = Join-Path $GameDir 'mods' }
    [IO.Directory]::CreateDirectory($mods) | Out-Null
    Say "Папка модов: $mods"

    if (Get-Process -Name javaw, java -ErrorAction SilentlyContinue) {
        Say "Похоже, Minecraft запущен. Закрой игру, иначе старые файлы не удалятся." Yellow
    }

    # Моды прежней Fabric-сборки NeoForge не загрузит, убираем их
    foreach ($pattern in $manifest.remove) {
        Get-ChildItem -LiteralPath $mods -Filter $pattern | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Say "Убран старый мод: $($_.Name)" Yellow
        }
    }

    # 3. Моды сборки
    foreach ($mod in $manifest.mods) {
        if ($mod.github) {
            # Наш мод: свежая dev-сборка или последний стабильный релиз из GitHub Releases
            $api = if ($Stable) { "https://api.github.com/repos/$($mod.github)/releases/latest" } else { "https://api.github.com/repos/$($mod.github)/releases/tags/$(if ($mod.devTag) { $mod.devTag } else { 'dev' })" }
            $release = Invoke-RestMethod $api -Headers $Headers
            $asset = $release.assets | Where-Object { $_.name -like $mod.asset -and $_.name -notlike '*-sources*' } | Select-Object -First 1
            if (-not $asset) { throw "$($mod.name): в релизе '$($release.name)' нет jar-файла." }
            $name = $asset.name
            $url = $asset.browser_download_url
            $sha = $null
        } else {
            # Чужой мод: точная версия с Modrinth, сверяем контрольную сумму
            $name = $mod.file
            $url = $mod.url
            $sha = $mod.sha512
        }
        if (Test-Path -LiteralPath (Join-Path $mods $name)) {
            Say "$($mod.name): уже последней версии ($name)" Green
            Remove-Old $mods $mod.replaces $name
            continue
        }
        $tmp = Join-Path $env:TEMP $name
        Invoke-WebRequest $url -OutFile $tmp -Headers $Headers -UseBasicParsing
        if ($sha -and ((Get-FileHash -LiteralPath $tmp -Algorithm SHA512).Hash.ToLower() -ne $sha.ToLower())) {
            Remove-Item -LiteralPath $tmp -Force
            throw "$($mod.name): файл скачался повреждённым (контрольная сумма не совпала). Попробуй ещё раз."
        }
        Remove-Old $mods $mod.replaces $name
        [IO.File]::Copy($tmp, (Join-Path $mods $name), $true)
        Remove-Item -LiteralPath $tmp -Force
        Say "$($mod.name): установлен $name" Green
    }

    Say ""
    Say "Готово! Запускай в TLauncher версию '$VersionName'." Cyan
}
catch {
    Say ""
    Say "Ошибка: $($_.Exception.Message)" Red
    exit 1
}
