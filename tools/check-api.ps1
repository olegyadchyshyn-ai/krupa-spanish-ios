# Перевірка відповідності викликів API оголошенням у проєкті.
#
# Ловить те, що не бачить компілятор на Windows: звернення до неіснуючих
# членів AppState / сервісів, прямий запис у computed-властивості профілю,
# відсутні екрани, які очікує RootView.
#
# Запуск:  & tools/check-api.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sourcesDir = Join-Path $root 'KrupaSpanish\Sources'
$problems = New-Object System.Collections.Generic.List[string]

function Get-TypeMembers {
    param([string]$Text, [string]$TypeName)

    $pattern = "(?:final\s+class|class|struct|enum)\s+$TypeName\b[^\{]*\{"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }

    # Знаходимо кінець тіла типу за балансом дужок.
    $start = $match.Index + $match.Length
    $depth = 1
    $index = $start
    while ($index -lt $Text.Length -and $depth -gt 0) {
        $ch = $Text[$index]
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') { $depth-- }
        $index++
    }
    $body = $Text.Substring($start, [Math]::Max(0, $index - $start - 1))

    $members = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in [regex]::Matches($body, '(?m)^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public\s+|private(?:\(set\))?\s+|internal\s+|static\s+|final\s+|override\s+|nonisolated\s+|@MainActor\s+)*(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)')) {
        [void]$members.Add($m.Groups[1].Value)
    }
    # Ініціалізатори (memberwise init) вважаємо наявними завжди.
    [void]$members.Add("init")
    return $members
}

function Read-TypeText {
    param([string]$RelativePath)
    $full = Join-Path $sourcesDir $RelativePath
    if (-not (Test-Path $full)) { return $null }
    return [System.IO.File]::ReadAllText($full)
}

# --- 1. Збираємо члени ключових типів ---
$typeFiles = @{
    'AppState'                  = 'App\AppState.swift'
    'ProgressStore'             = 'Data\ProgressStore.swift'
    'SpeechService'             = 'Speech\SpeechService.swift'
    'SpeechRecognitionService'  = 'Speech\SpeechService.swift'
    'AIService'                 = 'AI\AIService.swift'
    'BackupService'             = 'Data\BackupService.swift'
    'CourseContent'             = 'Models\ContentModels.swift'
    'SrsEngine'                 = 'Learning\SrsEngine.swift'
    'AnswerCheck'               = 'Learning\AnswerCheck.swift'
    'LessonBuilder'             = 'Learning\LessonBuilder.swift'
    'SessionChecker'            = 'Learning\LessonBuilder.swift'
    'PronunciationScorer'       = 'Speech\PronunciationScorer.swift'
    'SpanishPhonetics'          = 'Speech\PronunciationScorer.swift'
}

$members = @{}
foreach ($name in $typeFiles.Keys) {
    $text = Read-TypeText $typeFiles[$name]
    if ($null -eq $text) { continue }
    $set = Get-TypeMembers -Text $text -TypeName $name
    if ($null -ne $set) { $members[$name] = $set }
}

# Сервіси, доступні як властивості AppState.
$serviceTypes = @{
    'progress'    = 'ProgressStore'
    'speech'      = 'SpeechService'
    'recognition' = 'SpeechRecognitionService'
    'ai'          = 'AIService'
    'backup'      = 'BackupService'
    'content'     = 'CourseContent'
}

# --- 2. Перевіряємо виклики у файлах екранів ---
$screenDir = Join-Path $sourcesDir 'UI\Screens'
$screenFiles = @()
if (Test-Path $screenDir) {
    $screenFiles = Get-ChildItem $screenDir -Filter *.swift
}

$appStateMembers = $members['AppState']

foreach ($file in $screenFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName)

    if ($text -notmatch '@EnvironmentObject\s+private\s+var\s+app\s*:\s*AppState') {
        $problems.Add("$($file.Name): немає @EnvironmentObject private var app: AppState")
    }

    # Прямий запис у computed-властивості профілю/налаштувань — помилка компіляції.
    foreach ($m in [regex]::Matches($text, 'app\.progress\.(?:profile|settings)\.[A-Za-z_][A-Za-z0-9_]*\s*=[^=]')) {
        $problems.Add("$($file.Name): прямий запис у computed-властивість -> $($m.Value.Trim())")
    }
    foreach ($m in [regex]::Matches($text, 'app\.profile\.[A-Za-z_][A-Za-z0-9_]*\s*=[^=]')) {
        $problems.Add("$($file.Name): прямий запис у app.profile -> $($m.Value.Trim())")
    }

    # app.<member> — має існувати в AppState.
    foreach ($m in [regex]::Matches($text, 'app\.([a-zA-Z_][A-Za-z0-9_]*)')) {
        $member = $m.Groups[1].Value
        if ($serviceTypes.ContainsKey($member)) { continue }
        if ($null -ne $appStateMembers -and -not $appStateMembers.Contains($member)) {
            $problems.Add("$($file.Name): невідомий член AppState -> app.$member")
        }
    }

    # app.<service>.<member> — має існувати у відповідному типі.
    foreach ($m in [regex]::Matches($text, 'app\.([a-zA-Z_][A-Za-z0-9_]*)\.([a-zA-Z_][A-Za-z0-9_]*)')) {
        $service = $m.Groups[1].Value
        $member = $m.Groups[2].Value
        if (-not $serviceTypes.ContainsKey($service)) { continue }
        $typeName = $serviceTypes[$service]
        if (-not $members.ContainsKey($typeName)) { continue }
        if ($members[$typeName].Contains($member)) { continue }
        # Властивості моделей даних (Word, Topic тощо) тут не перевіряємо.
        $knownModelMembers = @('id', 'level', 'topicId', 'spanish', 'translationUk', 'titleUk', 'titleEs',
            'kind', 'count', 'first', 'last', 'isEmpty', 'allCases', 'rawValue', 'description')
        if ($knownModelMembers -contains $member) { continue }
        $problems.Add("$($file.Name): невідомий член $typeName -> app.$service.$member")
    }
}

# --- 3. Екрани, які очікує RootView ---
$rootView = Read-TypeText 'App\RootView.swift'
$required = @()
if ($null -ne $rootView) {
    foreach ($m in [regex]::Matches($rootView, '(?m)^\s*([A-Z][A-Za-z0-9_]*)Screen(?:\(|\s|\{)')) {
        $required += ($m.Groups[1].Value + 'Screen')
    }
    foreach ($m in [regex]::Matches($rootView, 'RouteView|ProgressDetailsScreen|DiagnosticsScreen|BackupScreen|AboutScreen|GrammarListScreen|GrammarDetailScreen|ListeningListScreen|ListeningDetailScreen|AIDialogScreen|SpeakingScreen|ReviewScreen|WordsListScreen|WordDetailScreen|TopicDetailScreen|SessionScreen')) {
        $required += $m.Value
    }
}
$required = $required | Select-Object -Unique
$declared = @{}
foreach ($file in (Get-ChildItem $sourcesDir -Recurse -Filter *.swift)) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($m in [regex]::Matches($text, '(?m)^\s*struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*View')) {
        $declared[$m.Groups[1].Value] = $file.Name
    }
}
foreach ($name in $required) {
    if (-not $declared.ContainsKey($name)) {
        $problems.Add("Не реалізовано екран: $name (очікується з RootView/RouteView)")
    }
}

# --- Підсумок ---
if ($problems.Count -eq 0) {
    Write-Host "API-перевірка: проблем не знайдено." -ForegroundColor Green
    exit 0
}
Write-Host "API-перевірка: знайдено $($problems.Count)" -ForegroundColor Yellow
foreach ($problem in $problems) { Write-Host " - $problem" }
exit 1
