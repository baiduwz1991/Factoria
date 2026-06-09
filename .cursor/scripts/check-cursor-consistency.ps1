param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cursorRoot = Join-Path $RepoRoot '.cursor'
$hubPath = Join-Path $cursorRoot 'README.md'
$skillsRoot = Join-Path $cursorRoot 'skills'

$errors = New-Object 'System.Collections.Generic.List[string]'
$checked = 0

function Add-Error {
    param([string]$Message)
    $script:errors.Add($Message)
}

function Resolve-ProjectPath {
    param(
        [string]$Root,
        [string]$RelativePath
    )

    $normalized = $RelativePath -replace '\\', '/'
    if ($normalized.StartsWith('.cursor/')) {
        $normalized = $normalized.Substring(8)
        $relative = $normalized -replace '/', '\'
        return Join-Path $Root (Join-Path '.cursor' $relative)
    }

    if ($normalized -match '^(rules|skills|docs|plans|roles)/') {
        return Join-Path (Join-Path $Root '.cursor') ($normalized -replace '/', '\')
    }

    return Join-Path $Root ($normalized -replace '/', '\')
}

function Should-CheckPath {
    param([string]$CodeSpan)

    if ([string]::IsNullOrWhiteSpace($CodeSpan)) { return $false }
    if ($CodeSpan.Contains('*')) { return $false }
    if ($CodeSpan.Contains('<') -or $CodeSpan.Contains('>')) { return $false }
    if ($CodeSpan -match '^[A-Za-z]+://') { return $false }

    return $CodeSpan -match '^(rules|skills|docs|plans|roles)/' -or $CodeSpan -match '^\.cursor/'
}

if (-not (Test-Path -LiteralPath $hubPath)) {
    throw "Hub file not found: $hubPath"
}

$hubContent = Get-Content -LiteralPath $hubPath -Raw -Encoding UTF8
$codeSpans = [regex]::Matches($hubContent, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -Unique

foreach ($code in $codeSpans) {
    if (-not (Should-CheckPath -CodeSpan $code)) { continue }

    $targetPath = Resolve-ProjectPath -Root $RepoRoot -RelativePath $code
    $checked += 1
    if (-not (Test-Path -LiteralPath $targetPath)) {
        Add-Error "Hub path missing: '$code' -> '$targetPath'"
    }
}

$skillFiles = Get-ChildItem -Path $skillsRoot -Recurse -File -Filter 'SKILL.md'
foreach ($skillFile in $skillFiles) {
    $lines = Get-Content -LiteralPath $skillFile.FullName -Encoding UTF8
    $frontmatterStart = -1
    $frontmatterEnd = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            if ($frontmatterStart -eq -1) {
                $frontmatterStart = $i
                continue
            }
            $frontmatterEnd = $i
            break
        }
    }

    if ($frontmatterStart -ne 0 -or $frontmatterEnd -le $frontmatterStart) {
        Add-Error "Skill frontmatter invalid: '$($skillFile.FullName)'"
        continue
    }

    $inDependsOn = $false
    for ($i = $frontmatterStart + 1; $i -lt $frontmatterEnd; $i++) {
        $trim = $lines[$i].Trim()

        if ($trim -eq 'depends_on:') {
            $inDependsOn = $true
            continue
        }

        if (-not $inDependsOn) { continue }

        if ($trim -match '^-\s+(.+)$') {
            $dep = $Matches[1].Trim()
        } elseif ($trim -match '^[A-Za-z_][A-Za-z0-9_]*:') {
            $inDependsOn = $false
            continue
        } else {
            continue
        }

        $checked += 1
        $depPath = Resolve-ProjectPath -Root $RepoRoot -RelativePath $dep
        if (-not (Test-Path -LiteralPath $depPath)) {
            Add-Error "Skill depends_on missing: '$dep' in '$($skillFile.FullName)'"
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "FAILED: .cursor consistency check ($($errors.Count) issues)"
    foreach ($err in $errors) {
        Write-Host "  - $err"
    }
    exit 1
}

Write-Host "OK: .cursor consistency check passed (checks: $checked)"
exit 0
