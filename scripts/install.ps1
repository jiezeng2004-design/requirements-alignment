#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Manual')]
    [string]$Mode,

    [ValidateSet('Install', 'Keep', 'Switch', 'Reinstall', 'Uninstall', 'Restore', 'Cancel')]
    [string]$Action,

    [ValidateSet('Ask', 'Enable', 'Skip', 'Keep', 'Remove')]
    [string]$NativeFeature = 'Ask',

    [string]$HomePath = [Environment]::GetFolderPath('UserProfile'),

    [string]$BackupPath,

    [switch]$NonInteractive,

    [switch]$SkipCapabilityCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:InstallerVersion = '0.1.0'
$script:StartMarker = '<!-- requirements-alignment:start -->'
$script:EndMarker = '<!-- requirements-alignment:end -->'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:DefaultHome = [IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')).TrimEnd('\')
$script:UserHome = [IO.Path]::GetFullPath($HomePath).TrimEnd('\')
$script:CodexHome = Join-Path $script:UserHome '.codex'
$script:AgentsRoot = Join-Path $script:UserHome '.agents'
$script:SkillsRoot = Join-Path $script:AgentsRoot 'skills'
$script:SkillRoot = Join-Path $script:SkillsRoot 'requirements-alignment'
$script:AgentsPath = Join-Path $script:CodexHome 'AGENTS.md'
$script:ConfigPath = Join-Path $script:CodexHome 'config.toml'
$script:BackupsRoot = Join-Path $script:CodexHome 'requirements-alignment-backups'
$script:AutoSnippetPath = Join-Path $script:RepoRoot 'snippets\AGENTS.auto.md'
$script:Utf8NoBom = New-Object Text.UTF8Encoding($false)

$script:LegacyAgentsBlock = @'
## Requirement alignment

- Inspect the repository, code, configuration, and prior context before asking the user. Do not ask for information that can already be confirmed from the project.
- Ask first when the answer would materially change system architecture, data storage or databases, public APIs, authentication or authorization, third-party services or important dependencies, compatibility strategy, product behavior or important UX, irreversible data deletion, or a scope ambiguity that would significantly expand the work.
- Decide and continue without asking for small mechanical edits, formatting, variable names, ordinary function extraction, information already available in the repository, low-risk and easily reversible implementation details, decisions with an obvious industry convention, or information the user has already provided.
- Favor autonomy for engineering decisions and user input for product, architecture, security, compatibility, and scope decisions.
- If `request_user_input` is available, prefer a structured question over a free-form text question. Ask at most 1-3 high-value questions at a time, put a clearly recommended option first, explain the key trade-off briefly, and ask the highest-impact dependent decision first.
- After alignment, treat the answer as a requirement, summarize the implementation direction briefly, and continue without reconfirming it unless a new blocking ambiguity appears.
'@

function Write-Title {
    Write-Host ''
    Write-Host 'Requirements Alignment for Codex' -ForegroundColor Cyan
    Write-Host "Installer v$($script:InstallerVersion)"
    Write-Host ''
}

function Read-MenuChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string[]]$Allowed
    )

    while ($true) {
        $answer = (Read-Host $Prompt).Trim()
        if ($answer -in $Allowed) { return $answer }
        Write-Host "Choose one of: $($Allowed -join ', ')" -ForegroundColor Yellow
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $suffix = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    while ($true) {
        $answer = (Read-Host "$Prompt $suffix").Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
        if ($answer -in @('y', 'yes')) { return $true }
        if ($answer -in @('n', 'no')) { return $false }
        Write-Host 'Enter Y or N.' -ForegroundColor Yellow
    }
}

function Get-NewLine {
    param([string]$Text)
    if ($Text -match "`r`n") { return "`r`n" }
    return "`n"
}

function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.File]::ReadAllText($Path)
}

function Write-TextFileAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    }

    $temporary = Join-Path $parent ('.requirements-alignment-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, $Content, $script:Utf8NoBom)
        Move-Item -LiteralPath $temporary -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction Stop
        }
    }
}

function Assert-NotReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to modify reparse point: $Path"
        }
    }
}

function Remove-SkillTreeSafely {
    if (-not (Test-Path -LiteralPath $script:SkillRoot)) { return }
    if (-not (Test-Path -LiteralPath $script:SkillRoot -PathType Container)) {
        throw "Installed skill path is not a directory: $($script:SkillRoot)"
    }

    Assert-NotReparsePoint -Path $script:SkillRoot
    $children = @(Get-ChildItem -LiteralPath $script:SkillRoot -Force -Recurse)
    $reparseChildren = @($children | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
    if ($reparseChildren.Count -ne 0) {
        throw "Refusing to remove skill containing reparse points: $($reparseChildren.FullName -join ', ')"
    }

    Remove-Item -LiteralPath $script:SkillRoot -Recurse -Force -ErrorAction Stop
}

function Get-InstalledState {
    $skillFile = Join-Path $script:SkillRoot 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        return [pscustomobject]@{ Installed = $false; Version = $null; Mode = $null; Legacy = $false }
    }

    $text = Read-TextFile -Path $skillFile
    $match = [regex]::Match($text, 'requirements-alignment:version=(?<version>[0-9]+\.[0-9]+\.[0-9]+);mode=(?<mode>auto|manual)')
    if ($match.Success) {
        return [pscustomobject]@{
            Installed = $true
            Version = $match.Groups['version'].Value
            Mode = (Get-Culture).TextInfo.ToTitleCase($match.Groups['mode'].Value)
            Legacy = $false
        }
    }

    return [pscustomobject]@{ Installed = $true; Version = 'unversioned'; Mode = $null; Legacy = $true }
}

function Get-ManagedBlockInfo {
    param([AllowEmptyString()][string]$Text)
    $startCount = [regex]::Matches($Text, [regex]::Escape($script:StartMarker)).Count
    $endCount = [regex]::Matches($Text, [regex]::Escape($script:EndMarker)).Count
    if ($startCount -ne $endCount -or $startCount -gt 1) {
        throw 'AGENTS.md has unmatched or duplicate requirements-alignment managed markers.'
    }
    return [pscustomobject]@{ Count = $startCount }
}

function Get-LegacyBlockRegex {
    $lines = $script:LegacyAgentsBlock -split "`r?`n"
    $escaped = @($lines | ForEach-Object { [regex]::Escape($_) })
    return '(?m)(?<![^\r\n])' + ($escaped -join '\r?\n') + '(?:\r?\n)?'
}

function Remove-LegacyBlockExact {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $pattern = Get-LegacyBlockRegex
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -gt 1) { throw 'Multiple exact legacy Requirement alignment sections found.' }
    if ($matches.Count -eq 1) {
        return [pscustomobject]@{ Text = [regex]::Replace($Text, $pattern, '', 1); Removed = $true }
    }
    return [pscustomobject]@{ Text = $Text; Removed = $false }
}

function Set-AutoAgentsBlock {
    $snippet = (Read-TextFile -Path $script:AutoSnippetPath).Trim()
    $existing = if (Test-Path -LiteralPath $script:AgentsPath -PathType Leaf) { Read-TextFile -Path $script:AgentsPath } else { '' }
    $newline = Get-NewLine -Text $existing
    $legacyResult = Remove-LegacyBlockExact -Text $existing
    $working = $legacyResult.Text
    if ($legacyResult.Removed) {
        Write-Host 'Migrating the exact legacy Requirement alignment section into a managed Auto block.' -ForegroundColor DarkCyan
    }

    $blockInfo = Get-ManagedBlockInfo -Text $working
    if ($blockInfo.Count -eq 1) {
        $pattern = '(?s)' + [regex]::Escape($script:StartMarker) + '.*?' + [regex]::Escape($script:EndMarker)
        $working = [regex]::Replace($working, $pattern, ($snippet -replace "`n", $newline), 1)
    }
    else {
        $prefix = $working.TrimEnd()
        if ([string]::IsNullOrWhiteSpace($prefix)) {
            $working = ($snippet -replace "`n", $newline) + $newline
        }
        else {
            $working = $prefix + $newline + $newline + ($snippet -replace "`n", $newline) + $newline
        }
    }

    Write-TextFileAtomic -Path $script:AgentsPath -Content $working
}

function Remove-AutoAgentsBlock {
    if (-not (Test-Path -LiteralPath $script:AgentsPath -PathType Leaf)) { return }
    $existing = Read-TextFile -Path $script:AgentsPath
    $newline = Get-NewLine -Text $existing
    $legacyResult = Remove-LegacyBlockExact -Text $existing
    $working = $legacyResult.Text
    if ($legacyResult.Removed) {
        Write-Host 'Removing the exact legacy Requirement alignment section.' -ForegroundColor DarkCyan
    }

    $blockInfo = Get-ManagedBlockInfo -Text $working
    if ($blockInfo.Count -eq 1) {
        $pattern = '(?s)(?:\r?\n){0,2}' + [regex]::Escape($script:StartMarker) + '.*?' + [regex]::Escape($script:EndMarker) + '(?:\r?\n)?'
        $working = [regex]::Replace($working, $pattern, '', 1).TrimEnd()
        if (-not [string]::IsNullOrWhiteSpace($working)) { $working += $newline }
    }

    if ([string]::IsNullOrWhiteSpace($working)) {
        Remove-Item -LiteralPath $script:AgentsPath -Force -ErrorAction Stop
    }
    else {
        Write-TextFileAtomic -Path $script:AgentsPath -Content $working
    }
}

function Get-ConfigFeatureInfo {
    $text = if (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf) { Read-TextFile -Path $script:ConfigPath } else { '' }
    $sectionCount = [regex]::Matches($text, '(?m)^[ \t]*\[features\][ \t]*(?:#.*)?\r?$').Count
    $anyTarget = [regex]::Matches($text, '(?m)^[ \t]*default_mode_request_user_input[ \t]*=').Count
    $validTarget = [regex]::Matches($text, '(?m)^[ \t]*default_mode_request_user_input[ \t]*=[ \t]*(?<value>true|false)[ \t]*(?:#.*)?\r?$')
    $status = 'Missing'
    if ($sectionCount -gt 1 -or $anyTarget -gt 1 -or $anyTarget -ne $validTarget.Count) {
        $status = 'Ambiguous'
    }
    elseif ($validTarget.Count -eq 1) {
        $status = if ($validTarget[0].Groups['value'].Value -eq 'true') { 'Enabled' } else { 'Disabled' }
    }
    return [pscustomobject]@{
        Text = $text
        ConfigExisted = Test-Path -LiteralPath $script:ConfigPath -PathType Leaf
        FeatureSectionCount = $sectionCount
        TargetCount = $anyTarget
        Status = $status
    }
}

function Get-CapabilityStatus {
    if ($SkipCapabilityCheck -or $script:UserHome -cne $script:DefaultHome) { return 'unknown' }
    $command = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $command) { return 'unknown' }
    try {
        $output = & codex features list 2>&1
        if ($LASTEXITCODE -ne 0) { return 'unknown' }
        if ($output -match '(?m)^default_mode_request_user_input\s+') { return 'recognized by current Codex CLI' }
        return 'not recognized by current Codex CLI'
    }
    catch {
        return 'unknown'
    }
}

function Assert-FeatureText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [bool]$ExpectedEnabled
    )
    $sections = [regex]::Matches($Text, '(?m)^[ \t]*\[features\][ \t]*(?:#.*)?\r?$').Count
    $targets = [regex]::Matches($Text, '(?m)^[ \t]*default_mode_request_user_input[ \t]*=[ \t]*(?<value>true|false)[ \t]*(?:#.*)?\r?$')
    if ($sections -gt 1) { throw 'TOML structural validation failed: duplicate [features] sections.' }
    if ($ExpectedEnabled) {
        if ($targets.Count -ne 1 -or $targets[0].Groups['value'].Value -ne 'true') {
            throw 'TOML structural validation failed: target feature is not uniquely true.'
        }
    }
    elseif ($targets.Count -ne 0) {
        throw 'TOML structural validation failed: target feature still exists.'
    }
}

function Enable-NativeFeature {
    $info = Get-ConfigFeatureInfo
    if ($info.Status -eq 'Enabled') {
        Write-Host 'Native request_user_input: enabled'
        return
    }
    if ($info.Status -eq 'Ambiguous') {
        throw 'Cannot safely modify config.toml because the target key or [features] section is ambiguous.'
    }

    $text = $info.Text
    $newline = Get-NewLine -Text $text
    if ($info.Status -eq 'Disabled') {
        $pattern = '(?m)^[ \t]*default_mode_request_user_input[ \t]*=[ \t]*false[ \t]*(?:#.*)?\r?$'
        $text = [regex]::Replace($text, $pattern, 'default_mode_request_user_input = true', 1)
    }
    elseif ($info.FeatureSectionCount -eq 1) {
        $header = [regex]::Match($text, '(?m)^[ \t]*\[features\][ \t]*(?:#.*)?(?:\r?\n|$)')
        if (-not $header.Success) { throw 'Unable to locate the existing [features] section.' }
        $text = $text.Insert($header.Index + $header.Length, 'default_mode_request_user_input = true' + $newline)
    }
    else {
        $prefix = $text.TrimEnd()
        if (-not [string]::IsNullOrWhiteSpace($prefix)) { $prefix += $newline + $newline }
        $text = $prefix + '[features]' + $newline + 'default_mode_request_user_input = true' + $newline
    }

    Assert-FeatureText -Text $text -ExpectedEnabled $true
    Write-TextFileAtomic -Path $script:ConfigPath -Content $text

    if (-not $SkipCapabilityCheck -and $script:UserHome -ceq $script:DefaultHome -and (Get-Command codex -ErrorAction SilentlyContinue)) {
        $output = & codex features list 2>&1
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?m)^default_mode_request_user_input\s+.*\btrue\s*$') {
            throw 'Codex did not confirm the feature as effectively enabled.'
        }
    }
}

function Remove-NativeFeature {
    if (-not (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)) { return }
    $info = Get-ConfigFeatureInfo
    if ($info.Status -eq 'Ambiguous') {
        throw 'Cannot safely remove the native feature because config.toml is ambiguous.'
    }
    if ($info.TargetCount -eq 0) { return }

    $pattern = '(?m)^[ \t]*default_mode_request_user_input[ \t]*=[ \t]*(?:true|false)[ \t]*(?:#.*)?(?:\r?\n)?'
    $text = [regex]::Replace($info.Text, $pattern, '', 1)
    Assert-FeatureText -Text $text -ExpectedEnabled $false
    Write-TextFileAtomic -Path $script:ConfigPath -Content $text
}

function Get-BackupFileRecords {
    param([Parameter(Mandatory = $true)][string]$BackupDirectory)
    $records = @()
    $files = @(Get-ChildItem -LiteralPath $BackupDirectory -File -Force -Recurse | Where-Object { $_.Name -ne 'manifest.json' })
    foreach ($file in $files) {
        $records += [pscustomobject]@{
            relative_path = $file.FullName.Substring($BackupDirectory.Length + 1)
            bytes = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    return $records
}

function New-BackupSnapshot {
    param([Parameter(Mandatory = $true)][string]$Reason)

    if (-not (Test-Path -LiteralPath $script:CodexHome -PathType Container)) {
        New-Item -ItemType Directory -Path $script:CodexHome -Force -ErrorAction Stop | Out-Null
    }
    Assert-NotReparsePoint -Path $script:CodexHome
    if (-not (Test-Path -LiteralPath $script:BackupsRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $script:BackupsRoot -Force -ErrorAction Stop | Out-Null
    }
    Assert-NotReparsePoint -Path $script:BackupsRoot

    $safeReason = $Reason -replace '[^a-zA-Z0-9-]', '-'
    $baseName = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $safeReason
    $backupDirectory = Join-Path $script:BackupsRoot $baseName
    $counter = 1
    while (Test-Path -LiteralPath $backupDirectory) {
        $backupDirectory = Join-Path $script:BackupsRoot ($baseName + '-' + $counter.ToString('00'))
        $counter++
    }
    New-Item -ItemType Directory -Path $backupDirectory -ErrorAction Stop | Out-Null

    $items = @()
    $skillExisted = Test-Path -LiteralPath $script:SkillRoot -PathType Container
    $agentsExisted = Test-Path -LiteralPath $script:AgentsPath -PathType Leaf
    $configExisted = Test-Path -LiteralPath $script:ConfigPath -PathType Leaf

    if ($skillExisted) { Copy-Item -LiteralPath $script:SkillRoot -Destination (Join-Path $backupDirectory 'skill') -Recurse -ErrorAction Stop }
    if ($agentsExisted) { Copy-Item -LiteralPath $script:AgentsPath -Destination (Join-Path $backupDirectory 'AGENTS.md') -ErrorAction Stop }
    if ($configExisted) { Copy-Item -LiteralPath $script:ConfigPath -Destination (Join-Path $backupDirectory 'config.toml') -ErrorAction Stop }

    $items += [pscustomobject]@{ kind = 'directory'; target = $script:SkillRoot; existed = $skillExisted; backup = 'skill' }
    $items += [pscustomobject]@{ kind = 'file'; target = $script:AgentsPath; existed = $agentsExisted; backup = 'AGENTS.md' }
    $items += [pscustomobject]@{ kind = 'file'; target = $script:ConfigPath; existed = $configExisted; backup = 'config.toml' }

    $manifest = [ordered]@{
        schema = 1
        installer = 'requirements-alignment'
        installer_version = $script:InstallerVersion
        reason = $Reason
        created_at = (Get-Date).ToString('o')
        home = $script:UserHome
        items = $items
        files = @(Get-BackupFileRecords -BackupDirectory $backupDirectory)
    }
    $manifestPath = Join-Path $backupDirectory 'manifest.json'
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $script:Utf8NoBom)
    Write-Host "Backup created: $backupDirectory" -ForegroundColor DarkCyan
    return $backupDirectory
}

function Test-BackupManifest {
    param([Parameter(Mandatory = $true)][string]$SnapshotPath)
    $manifestPath = Join-Path $SnapshotPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Backup manifest missing: $manifestPath" }
    $manifest = (Read-TextFile -Path $manifestPath) | ConvertFrom-Json
    if ($manifest.installer -ne 'requirements-alignment' -or -not $manifest.items) {
        throw 'The selected backup is not an installer-managed requirements-alignment snapshot.'
    }
    foreach ($file in $manifest.files) {
        $path = Join-Path $SnapshotPath $file.relative_path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Backup file missing: $path" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($hash -cne $file.sha256) { throw "Backup hash mismatch: $path" }
    }
    return $manifest
}

function Restore-BackupSnapshot {
    param([Parameter(Mandatory = $true)][string]$SnapshotPath)
    $resolvedRoot = (Resolve-Path -LiteralPath $script:BackupsRoot).Path
    $resolvedSnapshot = (Resolve-Path -LiteralPath $SnapshotPath).Path
    if (-not $resolvedSnapshot.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Selected backup is outside the requirements-alignment backup root.'
    }

    $manifest = Test-BackupManifest -SnapshotPath $resolvedSnapshot
    foreach ($item in $manifest.items) {
        $target = [string]$item.target
        if ($target -eq $script:SkillRoot) {
            if (Test-Path -LiteralPath $script:SkillRoot) { Remove-SkillTreeSafely }
            if ([bool]$item.existed) {
                Copy-Item -LiteralPath (Join-Path $resolvedSnapshot ([string]$item.backup)) -Destination $script:SkillRoot -Recurse -ErrorAction Stop
            }
        }
        elseif ($target -in @($script:AgentsPath, $script:ConfigPath)) {
            if ([bool]$item.existed) {
                $parent = Split-Path -Parent $target
                if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Copy-Item -LiteralPath (Join-Path $resolvedSnapshot ([string]$item.backup)) -Destination $target -Force -ErrorAction Stop
            }
            elseif (Test-Path -LiteralPath $target -PathType Leaf) {
                Remove-Item -LiteralPath $target -Force -ErrorAction Stop
            }
        }
        else {
            throw "Backup target does not match the current installation home: $target"
        }
    }
}

function Install-Profile {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Auto', 'Manual')][string]$SelectedMode,
        [bool]$ManageNativeFeature
    )

    $profilePath = Join-Path $script:RepoRoot ('profiles\' + $SelectedMode.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath (Join-Path $profilePath 'SKILL.md') -PathType Leaf)) {
        throw "Profile is incomplete: $profilePath"
    }

    $enableFeature = $false
    if ($ManageNativeFeature) {
        $featureInfo = Get-ConfigFeatureInfo
        if ($featureInfo.Status -eq 'Enabled') {
            Write-Host 'Native request_user_input: enabled' -ForegroundColor Green
        }
        else {
            $capability = Get-CapabilityStatus
            Write-Host "Native request_user_input capability: $capability"
            Write-Host 'This capability may be experimental or under development. The Skill can fall back to ordinary text questions.' -ForegroundColor Yellow
            if ($NativeFeature -eq 'Enable') { $enableFeature = $true }
            elseif ($NativeFeature -in @('Skip', 'Keep')) { $enableFeature = $false }
            elseif ($NonInteractive) { $enableFeature = $false }
            else { $enableFeature = Read-YesNo -Prompt 'Attempt to enable experimental native request_user_input support?' -DefaultYes $true }
        }
    }

    $backup = New-BackupSnapshot -Reason ('pre-' + $SelectedMode.ToLowerInvariant() + '-install')
    try {
        if (Test-Path -LiteralPath $script:SkillRoot) { Remove-SkillTreeSafely }
        New-Item -ItemType Directory -Path $script:SkillRoot -Force -ErrorAction Stop | Out-Null
        foreach ($item in @(Get-ChildItem -LiteralPath $profilePath -Force)) {
            Copy-Item -LiteralPath $item.FullName -Destination $script:SkillRoot -Recurse -ErrorAction Stop
        }

        if ($SelectedMode -eq 'Auto') { Set-AutoAgentsBlock }
        else { Remove-AutoAgentsBlock }

        if ($enableFeature) { Enable-NativeFeature }
    }
    catch {
        $failure = $_
        Write-Host 'Installation failed; restoring the pre-install snapshot.' -ForegroundColor Red
        Restore-BackupSnapshot -SnapshotPath $backup
        throw $failure
    }

    Write-Host ''
    Write-Host "Requirements Alignment v$($script:InstallerVersion) installed in $SelectedMode mode." -ForegroundColor Green
    Write-Host "Skill: $($script:SkillRoot)"
    if ($SelectedMode -eq 'Auto') { Write-Host 'Managed AGENTS block: installed' }
    else { Write-Host 'Managed AGENTS block: not installed' }
    Write-Host 'Restart Codex Desktop and start a new task to ensure configuration and instructions are reloaded.' -ForegroundColor Yellow
}

function Uninstall-RequirementsAlignment {
    $keepFeature = $true
    if ($NativeFeature -eq 'Remove') { $keepFeature = $false }
    elseif ($NativeFeature -in @('Keep', 'Skip', 'Enable')) { $keepFeature = $true }
    elseif (-not $NonInteractive) { $keepFeature = Read-YesNo -Prompt 'Keep native request_user_input feature enabled?' -DefaultYes $true }

    $backup = New-BackupSnapshot -Reason 'pre-uninstall'
    try {
        if (Test-Path -LiteralPath $script:SkillRoot) { Remove-SkillTreeSafely }
        Remove-AutoAgentsBlock
        if (-not $keepFeature) { Remove-NativeFeature }
    }
    catch {
        $failure = $_
        Write-Host 'Uninstall failed; restoring the pre-uninstall snapshot.' -ForegroundColor Red
        Restore-BackupSnapshot -SnapshotPath $backup
        throw $failure
    }

    Write-Host 'Requirements Alignment uninstalled.' -ForegroundColor Green
    if ($keepFeature) { Write-Host 'Native request_user_input feature was kept.' }
    else { Write-Host 'Native request_user_input feature setting was removed by explicit choice.' }
    Write-Host 'Restart Codex Desktop to reload Skills and instructions.' -ForegroundColor Yellow
}

function Select-BackupSnapshot {
    if ($BackupPath) { return $BackupPath }
    if ($NonInteractive) { throw 'Restore requires -BackupPath in non-interactive mode.' }
    if (-not (Test-Path -LiteralPath $script:BackupsRoot -PathType Container)) { throw 'No installer backups found.' }
    $snapshots = @(Get-ChildItem -LiteralPath $script:BackupsRoot -Directory | Where-Object {
        $manifestPath = Join-Path $_.FullName 'manifest.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $false }
        try {
            $candidate = (Read-TextFile -Path $manifestPath) | ConvertFrom-Json
            return ($candidate.installer -eq 'requirements-alignment' -and $null -ne $candidate.items)
        }
        catch {
            return $false
        }
    } | Sort-Object Name -Descending)
    if ($snapshots.Count -eq 0) { throw 'No installer-managed backups found.' }

    Write-Host 'Choose backup to restore:'
    for ($index = 0; $index -lt $snapshots.Count; $index++) {
        Write-Host "$($index + 1). $($snapshots[$index].Name)"
    }
    $allowed = 1..$snapshots.Count | ForEach-Object { $_.ToString() }
    $choice = [int](Read-MenuChoice -Prompt 'Backup' -Allowed $allowed)
    return $snapshots[$choice - 1].FullName
}

function Invoke-Restore {
    $selected = Select-BackupSnapshot
    $safety = New-BackupSnapshot -Reason 'pre-restore'
    try {
        Restore-BackupSnapshot -SnapshotPath $selected
    }
    catch {
        $failure = $_
        Write-Host 'Restore failed; returning to the pre-restore snapshot.' -ForegroundColor Red
        Restore-BackupSnapshot -SnapshotPath $safety
        throw $failure
    }
    Write-Host "Restored backup: $selected" -ForegroundColor Green
    Write-Host "Pre-restore safety backup: $safety"
    Write-Host 'Restart Codex Desktop to reload restored configuration.' -ForegroundColor Yellow
}

function Resolve-InteractiveAction {
    param([Parameter(Mandatory = $true)]$State)
    if (-not $State.Installed) {
        Write-Host 'Choose mode:'
        Write-Host ''
        Write-Host '1. Auto (Recommended)'
        Write-Host '   Automatically asks only when important decisions require your input.'
        Write-Host ''
        Write-Host '2. Manual'
        Write-Host '   Only intended to run when explicitly invoked.'
        Write-Host ''
        Write-Host '3. Restore backup'
        Write-Host '4. Cancel'
        $choice = Read-MenuChoice -Prompt 'Mode' -Allowed @('1', '2', '3', '4')
        if ($choice -eq '1') { return [pscustomobject]@{ Action = 'Install'; Mode = 'Auto' } }
        if ($choice -eq '2') { return [pscustomobject]@{ Action = 'Install'; Mode = 'Manual' } }
        if ($choice -eq '3') { return [pscustomobject]@{ Action = 'Restore'; Mode = $null } }
        return [pscustomobject]@{ Action = 'Cancel'; Mode = $null }
    }

    $current = if ($State.Legacy) { 'unversioned legacy installation' } else { "v$($State.Version) $($State.Mode) mode" }
    Write-Host "Requirements Alignment is currently installed: $current."
    Write-Host ''
    if ($State.Legacy) {
        Write-Host '1. Update to Auto (Recommended)'
        Write-Host '2. Update to Manual'
        Write-Host '3. Uninstall'
        Write-Host '4. Restore backup'
        Write-Host '5. Cancel'
        $choice = Read-MenuChoice -Prompt 'Action' -Allowed @('1', '2', '3', '4', '5')
        if ($choice -eq '1') { return [pscustomobject]@{ Action = 'Reinstall'; Mode = 'Auto' } }
        if ($choice -eq '2') { return [pscustomobject]@{ Action = 'Reinstall'; Mode = 'Manual' } }
        if ($choice -eq '3') { return [pscustomobject]@{ Action = 'Uninstall'; Mode = $null } }
        if ($choice -eq '4') { return [pscustomobject]@{ Action = 'Restore'; Mode = $null } }
        return [pscustomobject]@{ Action = 'Cancel'; Mode = $null }
    }

    $opposite = if ($State.Mode -eq 'Auto') { 'Manual' } else { 'Auto' }
    Write-Host "1. Keep $($State.Mode)"
    Write-Host "2. Switch to $opposite"
    Write-Host '3. Reinstall / Update'
    Write-Host '4. Uninstall'
    Write-Host '5. Restore backup'
    Write-Host '6. Cancel'
    $choice = Read-MenuChoice -Prompt 'Action' -Allowed @('1', '2', '3', '4', '5', '6')
    if ($choice -eq '1') { return [pscustomobject]@{ Action = 'Keep'; Mode = $State.Mode } }
    if ($choice -eq '2') { return [pscustomobject]@{ Action = 'Switch'; Mode = $opposite } }
    if ($choice -eq '3') { return [pscustomobject]@{ Action = 'Reinstall'; Mode = $State.Mode } }
    if ($choice -eq '4') { return [pscustomobject]@{ Action = 'Uninstall'; Mode = $null } }
    if ($choice -eq '5') { return [pscustomobject]@{ Action = 'Restore'; Mode = $null } }
    return [pscustomobject]@{ Action = 'Cancel'; Mode = $null }
}

Write-Title

if (-not (Test-Path -LiteralPath $script:UserHome -PathType Container)) {
    if ($NonInteractive) { New-Item -ItemType Directory -Path $script:UserHome -Force -ErrorAction Stop | Out-Null }
    else { throw "User home does not exist: $($script:UserHome)" }
}

Assert-NotReparsePoint -Path $script:CodexHome
Assert-NotReparsePoint -Path $script:AgentsRoot
Assert-NotReparsePoint -Path $script:SkillsRoot

$state = Get-InstalledState
if (-not $Action) {
    if ($NonInteractive) { throw '-Action is required in non-interactive mode.' }
    $selection = Resolve-InteractiveAction -State $state
    $Action = $selection.Action
    if (-not $Mode) { $Mode = $selection.Mode }
}

switch ($Action) {
    'Cancel' {
        Write-Host 'Cancelled.'
    }
    'Keep' {
        if (-not $state.Installed) { throw 'Requirements Alignment is not installed.' }
        Write-Host "Keeping the current installation: v$($state.Version) $($state.Mode)." -ForegroundColor Green
    }
    'Install' {
        if ($state.Installed) { throw 'Requirements Alignment is already installed. Use Reinstall, Switch, or Uninstall.' }
        if (-not $Mode) { throw 'Install requires -Mode Auto or Manual.' }
        Install-Profile -SelectedMode $Mode -ManageNativeFeature $true
    }
    'Reinstall' {
        if (-not $Mode) {
            if ($state.Mode) { $Mode = $state.Mode }
            else { throw 'Reinstalling a legacy installation requires -Mode Auto or Manual.' }
        }
        Install-Profile -SelectedMode $Mode -ManageNativeFeature $true
    }
    'Switch' {
        if (-not $state.Installed) { throw 'Requirements Alignment is not installed.' }
        if (-not $Mode) { throw 'Switch requires -Mode Auto or Manual.' }
        if ($state.Mode -eq $Mode -and -not $state.Legacy) {
            Write-Host "Already in $Mode mode. No changes made."
        }
        else {
            Install-Profile -SelectedMode $Mode -ManageNativeFeature $false
        }
    }
    'Uninstall' {
        if (-not $state.Installed) { Write-Host 'Requirements Alignment is not installed.' }
        else { Uninstall-RequirementsAlignment }
    }
    'Restore' {
        Invoke-Restore
    }
}
