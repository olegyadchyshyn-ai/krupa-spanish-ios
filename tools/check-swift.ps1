# Легка перевірка Swift-коду проєкту перед відправкою на збірку.
#
# Компілятора Swift на Windows немає, тому скрипт ловить найпоширеніші
# причини помилок збірки: дублікати назв типів між файлами, незбалансовані
# дужки, посилання на невідомі маршрути AppRoute.
#
# Запуск:  pwsh -File tools/check-swift.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sourcesDir = Join-Path $root 'KrupaSpanish\Sources'
$problems = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $sourcesDir)) {
    Write-Host "Не знайдено теку Sources: $sourcesDir" -ForegroundColor Red
    exit 1
}

$files = Get-ChildItem $sourcesDir -Recurse -Filter *.swift
Write-Host "Перевіряю файлів: $($files.Count)"

# --- 1. Дублікати назв типів (без private/fileprivate) ---
$typeOwners = @{}
foreach ($file in $files) {
    $lines = Get-Content $file.FullName
    foreach ($line in $lines) {
        $m = [regex]::Match($line, '^\s*(?:(?:public|internal|final|open|@MainActor|@objc)\s+)*(struct|class|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)')
        if (-not $m.Success) { continue }
        if ($line -match '^\s*(private|fileprivate)\s') { continue }
        $name = $m.Groups[2].Value
        if (-not $typeOwners.ContainsKey($name)) { $typeOwners[$name] = New-Object System.Collections.Generic.List[string] }
        $typeOwners[$name].Add($file.Name)
    }
}
foreach ($name in $typeOwners.Keys) {
    $owners = $typeOwners[$name] | Select-Object -Unique
    if ($owners.Count -gt 1) {
        $problems.Add("Дублікат типу '$name' у файлах: $($owners -join ', ')")
    }
}

# --- 2. Баланс дужок ---
foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    # грубо прибираємо рядкові літерали та коментарі
    $clean = [regex]::Replace($text, '//[^\n]*', '')
    $clean = [regex]::Replace($clean, '/\*.*?\*/', '', 'Singleline')
    $clean = [regex]::Replace($clean, '"(?:\\.|[^"\\])*"', '""')
    $open = ([regex]::Matches($clean, '\{')).Count
    $close = ([regex]::Matches($clean, '\}')).Count
    if ($open -ne $close) {
        $problems.Add("Незбалансовані дужки у $($file.Name): { = $open, } = $close")
    }
}

# --- 3. Маршрути AppRoute ---
$routeFile = Join-Path $sourcesDir 'App\AppRoute.swift'
if (Test-Path $routeFile) {
    $routeText = [System.IO.File]::ReadAllText($routeFile)
    $enumBody = [regex]::Match($routeText, 'enum\s+AppRoute\s*:[^{]*\{(.*?)\n\}', 'Singleline').Groups[1].Value
    $declared = @()
    foreach ($m in [regex]::Matches($enumBody, '(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)')) { $declared += $m.Groups[1].Value }

    foreach ($file in $files) {
        if ($file.Name -eq 'AppRoute.swift') { continue }
        $text = [System.IO.File]::ReadAllText($file.FullName)
        foreach ($m in [regex]::Matches($text, 'AppRoute\.([A-Za-z_][A-Za-z0-9_]*)')) {
            $used = $m.Groups[1].Value
            if ($used -eq 'self') { continue }
            if ($declared -notcontains $used) {
                $problems.Add("$($file.Name): посилання на неіснуючий маршрут AppRoute.$used")
            }
        }
    }
}

# --- 4. Заборонені конструкції ---
foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($pattern in @('try!', 'as!', 'fatalError\(', '@Observable', 'import SwiftData', 'import Charts')) {
        $count = ([regex]::Matches($text, [regex]::Escape($pattern))).Count
        if ($count -gt 0) {
            $problems.Add("$($file.Name): заборонена конструкція '$pattern' ($count)")
        }
    }
}

# --- Підсумок ---
if ($problems.Count -eq 0) {
    Write-Host "Проблем не знайдено." -ForegroundColor Green
    exit 0
}

Write-Host "Знайдено проблем: $($problems.Count)" -ForegroundColor Yellow
foreach ($problem in $problems) { Write-Host " - $problem" }
exit 1
