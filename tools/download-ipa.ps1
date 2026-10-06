# Завантажує готовий .ipa з GitHub Actions на цей комп'ютер.
#
# Запуск (у теці проєкту):
#   & tools\download-ipa.ps1 -Repo "ЛОГІН/НАЗВА" -Token "ghp_..."
#
# Токен створюється тут: https://github.com/settings/tokens
#   • Fine-grained token → Repository access: потрібний репозиторій,
#     Permissions → Actions: Read-only.
#   • Або класичний token зі scope `repo` (для приватного репозиторію).
#
# Токен ніде не зберігається — використовується лише для цього запуску.

param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [string]$ArtifactName = 'KrupaSpanish-unsigned-ipa',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = $root }

$headers = @{
    Authorization          = "Bearer $Token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'krupa-spanish-downloader'
}

Write-Host "Шукаю артефакт «$ArtifactName» у репозиторії $Repo…" -ForegroundColor Cyan

$listUrl = "https://api.github.com/repos/$Repo/actions/artifacts?per_page=50"
$list = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get

if (-not $list.artifacts -or $list.artifacts.Count -eq 0) {
    Write-Host 'Артефактів не знайдено. Спершу дочекайтеся завершення збірки в розділі Actions.' -ForegroundColor Yellow
    exit 1
}

$artifact = $list.artifacts |
    Where-Object { $_.name -eq $ArtifactName -and -not $_.expired } |
    Sort-Object created_at -Descending |
    Select-Object -First 1

if (-not $artifact) {
    Write-Host "Артефакт «$ArtifactName» не знайдено (можливо, ще збирається або протермінований)." -ForegroundColor Yellow
    Write-Host 'Доступні артефакти:'
    $list.artifacts | Select-Object name, created_at, expired | Format-Table -AutoSize
    exit 1
}

Write-Host ("Знайдено: {0}, створено {1}, розмір {2:N0} КБ" -f $artifact.name, $artifact.created_at, ($artifact.size_in_bytes / 1KB))

$zipPath = Join-Path $env:TEMP ("krupa-ipa-" + [guid]::NewGuid().ToString('N') + '.zip')
Write-Host 'Завантажую…'
Invoke-WebRequest -Uri $artifact.archive_download_url -Headers $headers -OutFile $zipPath

$extractPath = Join-Path $env:TEMP ("krupa-ipa-" + [guid]::NewGuid().ToString('N'))
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$ipa = Get-ChildItem $extractPath -Recurse -Filter *.ipa | Select-Object -First 1
if (-not $ipa) {
    Write-Host 'У архіві немає файлу .ipa — перевірте лог збірки.' -ForegroundColor Red
    exit 1
}

$target = Join-Path $OutputDirectory $ipa.Name
Copy-Item $ipa.FullName $target -Force

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "Готово: $target" -ForegroundColor Green
Write-Host ("Розмір: {0:N1} МБ" -f ((Get-Item $target).Length / 1MB))
Write-Host ''
Write-Host 'Далі: цей файл можна передати будь-яким способом (WhatsApp, Telegram, пошта)'
Write-Host 'людині, яка підключить iPhone кабелем до комп''ютера й встановить через Sideloadly.'
Write-Host 'Інструкція: docs\install-ios-17.md'
