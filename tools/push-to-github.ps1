# Завантажує проєкт на GitHub, щоб хмарна збірка почала робити .ipa.
#
# Запуск (у теці проєкту):
#   & tools\push-to-github.ps1 -RepoUrl https://github.com/ЛОГІН/НАЗВА.git
#
# Скрипт нічого не видаляє: лише додає remote (або оновлює його) і робить push.

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Тека проєкту: $root" -ForegroundColor Cyan

# 1. Перевіряємо, що це git-репозиторій
if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Host 'Ініціалізую git-репозиторій…'
    git init -q
    git branch -M $Branch
}

# 2. Комітимо все, що ще не закомічено
$status = git status --porcelain
if ($status) {
    Write-Host 'Комічу зміни…'
    git add -A
    git -c core.quotepath=false commit -q -m "Оновлення проєкту KRUPA Spanish"
}

# 3. Налаштовуємо remote
$existing = git remote get-url origin 2>$null
if ($existing) {
    Write-Host "Remote origin уже вказує на $existing — оновлюю на $RepoUrl"
    git remote set-url origin $RepoUrl
} else {
    Write-Host "Додаю remote origin → $RepoUrl"
    git remote add origin $RepoUrl
}

# 4. Пуш
Write-Host 'Надсилаю файли на GitHub…'
git push -u origin $Branch
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'Не вдалося надіслати. Найчастіші причини:' -ForegroundColor Yellow
    Write-Host '  • репозиторій не створено на GitHub (створіть порожній, без README);'
    Write-Host '  • потрібна авторизація: GitHub попросить логін і токен замість пароля.'
    exit 1
}

# 5. Підсказуємо, де дивитися результат
$slug = ($RepoUrl -replace '^https://github\.com/', '' -replace '\.git$', '')
$actionsUrl = "https://github.com/$slug/actions"
$pagesUrl = "https://$($slug.Split('/')[0]).github.io/$($slug.Split('/')[1])/"

Write-Host ''
Write-Host 'Готово! Файли на GitHub.' -ForegroundColor Green
Write-Host ''
Write-Host 'Далі:'
Write-Host "  1) Збірка .ipa:   $actionsUrl"
Write-Host "     (workflow «Build iOS IPA» → Artifacts → KrupaSpanish-unsigned-ipa)"
Write-Host ''
Write-Host '  2) Веб-версія для дитини — увімкніть один раз:'
Write-Host "     https://github.com/$slug/settings/pages → Source: GitHub Actions"
Write-Host "     Посилання буде: $pagesUrl"
Write-Host ''
