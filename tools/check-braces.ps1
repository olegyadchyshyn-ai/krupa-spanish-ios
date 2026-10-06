# Точна перевірка балансу дужок у Swift-файлах.
#
# Враховує рядкові літерали ("..."), багаторядкові літерали ("""..."""),
# інтерполяцію, коментарі // та /* */. Потрібна тому, що наївний підрахунок
# дужок дає хибні тривоги, якщо в коді є JSON або шаблони в рядках.
#
# Запуск:  & tools/check-braces.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sourcesDir = Join-Path $root 'KrupaSpanish\Sources'

function Measure-Braces {
    param([string]$Text)

    $state = 'code'
    $depth = 0
    $line = 1
    $maxDepth = 0
    $closeAtTopLevel = New-Object System.Collections.Generic.List[int]
    $i = 0
    $n = $Text.Length

    while ($i -lt $n) {
        $c = $Text[$i]
        $next = if ($i + 1 -lt $n) { $Text[$i + 1] } else { [char]0 }
        $third = if ($i + 2 -lt $n) { $Text[$i + 2] } else { [char]0 }

        if ($c -eq "`n") { $line++ }

        if ($state -eq 'code') {
            if ($c -eq '/' -and $next -eq '/') { $state = 'linecomment'; $i++ }
            elseif ($c -eq '/' -and $next -eq '*') { $state = 'blockcomment'; $i++ }
            elseif ($c -eq '"' -and $next -eq '"' -and $third -eq '"') { $state = 'multistring'; $i += 2 }
            elseif ($c -eq '"') { $state = 'string' }
            elseif ($c -eq '{') {
                $depth++
                if ($depth -gt $maxDepth) { $maxDepth = $depth }
            }
            elseif ($c -eq '}') {
                $depth--
                if ($depth -le 1) { $closeAtTopLevel.Add($line) }
            }
        }
        elseif ($state -eq 'linecomment') {
            if ($c -eq "`n") { $state = 'code' }
        }
        elseif ($state -eq 'blockcomment') {
            if ($c -eq '*' -and $next -eq '/') { $state = 'code'; $i++ }
        }
        elseif ($state -eq 'string') {
            if ($c -eq '\') { $i++ }
            elseif ($c -eq '"') { $state = 'code' }
        }
        elseif ($state -eq 'multistring') {
            if ($c -eq '"' -and $next -eq '"' -and $third -eq '"') { $state = 'code'; $i += 2 }
        }

        $i++
    }

    return [pscustomobject]@{
        Depth      = $depth
        MaxDepth   = $maxDepth
        EndState   = $state
        Line       = $line
        TopCloses  = $closeAtTopLevel
    }
}

$problems = New-Object System.Collections.Generic.List[string]
$files = Get-ChildItem $sourcesDir -Recurse -Filter *.swift
Write-Host "Перевіряю файлів: $($files.Count)"

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $result = Measure-Braces -Text $text

    if ($result.Depth -ne 0) {
        $lastClose = if ($result.TopCloses.Count -gt 0) { ($result.TopCloses | Select-Object -Last 1) } else { 0 }
        $problems.Add("$($file.Name): не закрито блоків: $($result.Depth) (останній top-level закрився на рядку $lastClose, усього рядків $($result.Line))")
    }
    if ($result.EndState -ne 'code') {
        $problems.Add("$($file.Name): файл обривається всередині $($result.EndState)")
    }
}

if ($problems.Count -eq 0) {
    Write-Host "Дужки збалансовані у всіх файлах." -ForegroundColor Green
    exit 0
}

Write-Host "Знайдено проблем: $($problems.Count)" -ForegroundColor Yellow
foreach ($problem in $problems) { Write-Host " - $problem" }
exit 1
