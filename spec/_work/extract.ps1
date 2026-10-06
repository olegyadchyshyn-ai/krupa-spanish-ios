# Extract baksmali class sections by descriptor. ASCII-only (PowerShell 5.1 reads files as ANSI).
# Usage:  .\extract.ps1 -Class 'Lua/krupa/spanish/speech/tts/SpanishTtsEngine;'
param(
  [Parameter(Mandatory=$true)][string[]]$Class,
  [string]$OutDir
)
$root = $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'classes' }
$disasm = 'C:\Users\olegy\AppData\Local\Temp\dsh-ctDS1R\krupa_ios\disasm'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$rows = Import-Csv (Join-Path $root 'class_index.csv')
foreach ($c in $Class) {
  $row = $rows | Where-Object { $_.Class -eq $c }
  if (-not $row) { Write-Host "NOT FOUND: $c"; continue }
  $lines = [System.IO.File]::ReadAllLines((Join-Path $disasm $row.File))
  $start = [int]$row.Line
  $end = $lines.Count
  for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*Class descriptor  : '") { $end = $i; break }
  }
  $safe = ($c -replace '[\\/:*?"<>|;]','_')
  $out = Join-Path $OutDir "$safe.txt"
  $lines[($start-1)..($end-1)] | Set-Content -Encoding UTF8 $out
  Write-Host "$c -> $safe.txt  ($($end-$start) lines)"
}
