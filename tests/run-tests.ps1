#requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repoRoot 'scripts\install.ps1'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('requirements-alignment-tests-' + [guid]::NewGuid().ToString('N'))
$passed = 0

function Write-TestFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    $script:passed++
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Actual -cne $Expected) {
        throw "ASSERTION FAILED: $Message. Expected '$Expected', got '$Actual'."
    }
    $script:passed++
}

function Invoke-TestInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$UserHome,
        [Parameter(Mandatory = $true)][string[]]$InstallerArguments
    )
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $installer,
        '-NonInteractive',
        '-SkipCapabilityCheck',
        '-HomePath', $UserHome
    ) + $InstallerArguments
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Installer failed with exit code ${LASTEXITCODE}: $($InstallerArguments -join ' ')"
    }
}

function New-TestHome {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$AgentsText = "# User rules`r`n`r`n- Preserve this rule.`r`n",
        [string]$ConfigText = "model = `"test-model`"`r`n`r`n[features]`r`nmemories = true`r`nfast_mode = false`r`n`r`n[example]`r`nvalue = `"keep`"`r`n"
    )
    $testUserHome = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $testUserHome -Force | Out-Null
    Write-TestFile -Path (Join-Path $testUserHome '.codex\AGENTS.md') -Content $AgentsText
    Write-TestFile -Path (Join-Path $testUserHome '.codex\config.toml') -Content $ConfigText
    return $testUserHome
}

function Get-Count {
    param([string]$Text, [string]$Pattern)
    return [regex]::Matches($Text, $Pattern).Count
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    Write-Host "Test root: $testRoot" -ForegroundColor DarkCyan

    $homeAuto = New-TestHome -Name 'auto-cycle'
    $autoAgentsPath = Join-Path $homeAuto '.codex\AGENTS.md'
    $autoConfigPath = Join-Path $homeAuto '.codex\config.toml'
    $autoSkillPath = Join-Path $homeAuto '.agents\skills\requirements-alignment\SKILL.md'

    Invoke-TestInstaller -UserHome $homeAuto -InstallerArguments @('-Action', 'Install', '-Mode', 'Auto', '-NativeFeature', 'Enable')
    $agents = [IO.File]::ReadAllText($autoAgentsPath)
    $config = [IO.File]::ReadAllText($autoConfigPath)
    $skill = [IO.File]::ReadAllText($autoSkillPath)
    Assert-True ($skill -match 'requirements-alignment:version=0\.1\.0;mode=auto') 'fresh Auto installs the Auto profile'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 1 'fresh Auto creates one managed block'
    Assert-True ($agents -match [regex]::Escape('- Preserve this rule.')) 'fresh Auto preserves existing AGENTS content'
    Assert-Equal (Get-Count $config '(?m)^\[features\][ \t]*\r?$') 1 'fresh Auto preserves one features section'
    Assert-Equal (Get-Count $config '(?m)^default_mode_request_user_input\s*=\s*true[ \t]*\r?$') 1 'fresh Auto enables the feature once'
    Assert-True ($config -match '(?m)^memories\s*=\s*true[ \t]*\r?$') 'fresh Auto preserves existing features'

    Invoke-TestInstaller -UserHome $homeAuto -InstallerArguments @('-Action', 'Reinstall', '-Mode', 'Auto', '-NativeFeature', 'Keep')
    $agents = [IO.File]::ReadAllText($autoAgentsPath)
    $config = [IO.File]::ReadAllText($autoConfigPath)
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 1 'reinstall does not duplicate the managed block'
    Assert-Equal (Get-Count $config '(?m)^\[features\][ \t]*\r?$') 1 'reinstall does not duplicate the features section'
    Assert-Equal (Get-Count $config '(?m)^default_mode_request_user_input\s*=\s*true[ \t]*\r?$') 1 'reinstall does not duplicate the feature key'

    Invoke-TestInstaller -UserHome $homeAuto -InstallerArguments @('-Action', 'Switch', '-Mode', 'Manual', '-NativeFeature', 'Keep')
    $agents = [IO.File]::ReadAllText($autoAgentsPath)
    $config = [IO.File]::ReadAllText($autoConfigPath)
    $skill = [IO.File]::ReadAllText($autoSkillPath)
    Assert-True ($skill -match 'requirements-alignment:version=0\.1\.0;mode=manual') 'Auto to Manual replaces the profile'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 0 'Auto to Manual removes only the managed block'
    Assert-True ($agents -match [regex]::Escape('- Preserve this rule.')) 'Auto to Manual preserves user AGENTS content'
    Assert-Equal (Get-Count $config '(?m)^default_mode_request_user_input\s*=\s*true[ \t]*\r?$') 1 'mode switching does not change the feature'

    Invoke-TestInstaller -UserHome $homeAuto -InstallerArguments @('-Action', 'Switch', '-Mode', 'Auto', '-NativeFeature', 'Keep')
    $agents = [IO.File]::ReadAllText($autoAgentsPath)
    $skill = [IO.File]::ReadAllText($autoSkillPath)
    Assert-True ($skill -match 'requirements-alignment:version=0\.1\.0;mode=auto') 'Manual to Auto replaces the profile'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 1 'Manual to Auto restores one managed block'

    Invoke-TestInstaller -UserHome $homeAuto -InstallerArguments @('-Action', 'Uninstall', '-NativeFeature', 'Keep')
    $agents = [IO.File]::ReadAllText($autoAgentsPath)
    $config = [IO.File]::ReadAllText($autoConfigPath)
    Assert-True (-not (Test-Path -LiteralPath (Split-Path -Parent $autoSkillPath))) 'uninstall removes the installed skill directory'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 0 'uninstall removes the managed block'
    Assert-True ($agents -match [regex]::Escape('- Preserve this rule.')) 'uninstall preserves user AGENTS content'
    Assert-Equal (Get-Count $config '(?m)^default_mode_request_user_input\s*=\s*true[ \t]*\r?$') 1 'uninstall keeps the feature by default choice'

    $homeManual = New-TestHome -Name 'fresh-manual'
    $manualAgentsPath = Join-Path $homeManual '.codex\AGENTS.md'
    $manualConfigPath = Join-Path $homeManual '.codex\config.toml'
    $manualSkillPath = Join-Path $homeManual '.agents\skills\requirements-alignment\SKILL.md'
    Invoke-TestInstaller -UserHome $homeManual -InstallerArguments @('-Action', 'Install', '-Mode', 'Manual', '-NativeFeature', 'Skip')
    $agents = [IO.File]::ReadAllText($manualAgentsPath)
    $config = [IO.File]::ReadAllText($manualConfigPath)
    $skill = [IO.File]::ReadAllText($manualSkillPath)
    Assert-True ($skill -match 'requirements-alignment:version=0\.1\.0;mode=manual') 'fresh Manual installs the Manual profile'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 0 'fresh Manual does not add an AGENTS block'
    Assert-Equal (Get-Count $config '(?m)^default_mode_request_user_input\s*=') 0 'fresh Manual can skip feature enablement'

    $homeEmpty = Join-Path $testRoot 'fresh-empty'
    New-Item -ItemType Directory -Path $homeEmpty -Force | Out-Null
    Invoke-TestInstaller -UserHome $homeEmpty -InstallerArguments @('-Action', 'Install', '-Mode', 'Auto', '-NativeFeature', 'Enable')
    $emptyAgentsPath = Join-Path $homeEmpty '.codex\AGENTS.md'
    $emptyConfigPath = Join-Path $homeEmpty '.codex\config.toml'
    Assert-True (Test-Path -LiteralPath $emptyAgentsPath -PathType Leaf) 'fresh empty Auto creates AGENTS.md'
    Assert-True (Test-Path -LiteralPath $emptyConfigPath -PathType Leaf) 'fresh empty Auto creates config.toml when enabling the feature'
    $emptyConfig = [IO.File]::ReadAllText($emptyConfigPath)
    Assert-Equal (Get-Count $emptyConfig '(?m)^\[features\][ \t]*\r?$') 1 'fresh empty Auto creates one features section'
    Assert-Equal (Get-Count $emptyConfig '(?m)^default_mode_request_user_input\s*=\s*true[ \t]*\r?$') 1 'fresh empty Auto enables the feature once'
    Invoke-TestInstaller -UserHome $homeEmpty -InstallerArguments @('-Action', 'Uninstall', '-NativeFeature', 'Remove')
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeEmpty '.agents\skills\requirements-alignment'))) 'explicit uninstall removes the skill'
    Assert-True (-not (Test-Path -LiteralPath $emptyAgentsPath)) 'uninstall removes AGENTS.md when it contained only the managed block'
    $emptyConfig = [IO.File]::ReadAllText($emptyConfigPath)
    Assert-Equal (Get-Count $emptyConfig '(?m)^default_mode_request_user_input\s*=') 0 'explicit uninstall can remove the feature setting'

    $restoreAgents = "# Restore baseline`r`n`r`n- Keep me byte-for-byte.`r`n"
    $restoreConfig = "[features]`r`nmemories = true`r`n"
    $homeRestore = New-TestHome -Name 'restore' -AgentsText $restoreAgents -ConfigText $restoreConfig
    Invoke-TestInstaller -UserHome $homeRestore -InstallerArguments @('-Action', 'Install', '-Mode', 'Auto', '-NativeFeature', 'Enable')
    $backupRoot = Join-Path $homeRestore '.codex\requirements-alignment-backups'
    $installBackup = Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object Name | Select-Object -First 1
    Assert-True ($null -ne $installBackup) 'install creates a backup snapshot'
    Invoke-TestInstaller -UserHome $homeRestore -InstallerArguments @('-Action', 'Restore', '-BackupPath', $installBackup.FullName, '-NativeFeature', 'Keep')
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeRestore '.agents\skills\requirements-alignment'))) 'restore removes a skill that did not exist in the snapshot'
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $homeRestore '.codex\AGENTS.md'))) $restoreAgents 'restore recovers AGENTS exactly'
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $homeRestore '.codex\config.toml'))) $restoreConfig 'restore recovers config exactly'

    $legacyAgents = "# Existing rules`r`n`r`n" + (($scriptText = @'
## Requirement alignment

- Inspect the repository, code, configuration, and prior context before asking the user. Do not ask for information that can already be confirmed from the project.
- Ask first when the answer would materially change system architecture, data storage or databases, public APIs, authentication or authorization, third-party services or important dependencies, compatibility strategy, product behavior or important UX, irreversible data deletion, or a scope ambiguity that would significantly expand the work.
- Decide and continue without asking for small mechanical edits, formatting, variable names, ordinary function extraction, information already available in the repository, low-risk and easily reversible implementation details, decisions with an obvious industry convention, or information the user has already provided.
- Favor autonomy for engineering decisions and user input for product, architecture, security, compatibility, and scope decisions.
- If `request_user_input` is available, prefer a structured question over a free-form text question. Ask at most 1-3 high-value questions at a time, put a clearly recommended option first, explain the key trade-off briefly, and ask the highest-impact dependent decision first.
- After alignment, treat the answer as a requirement, summarize the implementation direction briefly, and continue without reconfirming it unless a new blocking ambiguity appears.
'@) -replace "`n", "`r`n") + "`r`n"
    $homeLegacy = New-TestHome -Name 'legacy' -AgentsText $legacyAgents
    $legacySkillRoot = Join-Path $homeLegacy '.agents\skills\requirements-alignment'
    New-Item -ItemType Directory -Path (Join-Path $legacySkillRoot 'agents') -Force | Out-Null
    Write-TestFile -Path (Join-Path $legacySkillRoot 'SKILL.md') -Content "---`nname: requirements-alignment`ndescription: Legacy test.`n---`n"
    Write-TestFile -Path (Join-Path $legacySkillRoot 'agents\openai.yaml') -Content "interface:`n  display_name: `"Legacy`"`n"
    Invoke-TestInstaller -UserHome $homeLegacy -InstallerArguments @('-Action', 'Reinstall', '-Mode', 'Auto', '-NativeFeature', 'Skip')
    $agents = [IO.File]::ReadAllText((Join-Path $homeLegacy '.codex\AGENTS.md'))
    Assert-Equal (Get-Count $agents '(?m)^## Requirement alignment\s*$') 0 'exact legacy section is migrated, not duplicated'
    Assert-Equal (Get-Count $agents '<!-- requirements-alignment:start -->') 1 'legacy migration creates one managed block'
    Assert-True ($agents -match [regex]::Escape('# Existing rules')) 'legacy migration preserves unrelated AGENTS content'

    $autoSkill = [IO.File]::ReadAllText((Join-Path $repoRoot 'profiles\auto\SKILL.md'))
    $manualSkill = [IO.File]::ReadAllText((Join-Path $repoRoot 'profiles\manual\SKILL.md'))
    $autoBody = [regex]::Match($autoSkill, '(?s)^---.*?---\s*(?<body>.*)$').Groups['body'].Value -replace '<!-- requirements-alignment:version=0\.1\.0;mode=auto -->\s*', ''
    $manualBody = [regex]::Match($manualSkill, '(?s)^---.*?---\s*(?<body>.*)$').Groups['body'].Value -replace '<!-- requirements-alignment:version=0\.1\.0;mode=manual -->\s*', ''
    Assert-Equal $autoBody $manualBody 'Auto and Manual share the same execution logic'
    $autoYaml = [IO.File]::ReadAllText((Join-Path $repoRoot 'profiles\auto\agents\openai.yaml'))
    $manualYaml = [IO.File]::ReadAllText((Join-Path $repoRoot 'profiles\manual\agents\openai.yaml'))
    Assert-True ($autoYaml -match '(?m)^\s*allow_implicit_invocation:\s*true\s*$') 'Auto allows implicit invocation'
    Assert-True ($manualYaml -match '(?m)^\s*allow_implicit_invocation:\s*false\s*$') 'Manual disables implicit invocation'

    $autoFrontmatter = [regex]::Match($autoSkill, '(?s)^---\s*(?<frontmatter>.*?)\s*---').Groups['frontmatter'].Value
    $manualFrontmatter = [regex]::Match($manualSkill, '(?s)^---\s*(?<frontmatter>.*?)\s*---').Groups['frontmatter'].Value
    Assert-True ($autoFrontmatter -match 'greenfield projects') 'Auto metadata names greenfield projects as a trigger'
    Assert-True ($autoFrontmatter -match 'blank repositories') 'Auto metadata names blank repositories as a trigger'
    Assert-True ($autoFrontmatter -match 'unclear product direction') 'Auto metadata targets unclear product direction'
    Assert-True ($autoFrontmatter -match 'reversible, low-risk, or common implementation defaults') 'Auto metadata rejects implementation defaults as product decisions'
    Assert-True ($autoFrontmatter -match 'explicit low-risk changes') 'Auto metadata excludes explicit low-risk work'
    Assert-True ($autoFrontmatter -notmatch 'Conservatively align high-impact requirements') 'Auto metadata no longer uses the blocking-only positioning'
    Assert-True ($manualFrontmatter -match 'Greenfield Alignment Gate') 'Manual metadata uses the same greenfield direction principle'
    Assert-True ($autoBody -match '## Greenfield Alignment Gate') 'shared workflow contains the Greenfield Alignment Gate'
    Assert-True ($autoBody -match '## Direction-defining decisions') 'shared workflow defines direction-defining decisions'
    Assert-True ($autoBody -match '1\. Product goal or user goal') 'shared workflow prioritizes product goal first'
    Assert-True ($autoBody -match '6\. Implementation details') 'shared workflow places implementation details last'
    Assert-True ($autoBody -match 'Do not ask all three automatically') 'greenfield gate avoids a fixed questionnaire'
    Assert-True ($autoBody -match 'Stop asking as soon as') 'greenfield gate has an explicit stopping condition'
    Assert-True ($autoBody -match 'Do not silently default a new product to Web, local storage, no account, or no backend') 'shared workflow prohibits reversible defaults from deciding product direction'
    Assert-True ($autoYaml -match 'short_description:\s*"Align unclear product direction before implementation"') 'Auto UI metadata describes direction alignment'
    Assert-True ($autoYaml -match 'default_prompt:\s*"Use \$requirements-alignment to align unclear greenfield product direction') 'Auto default prompt describes greenfield alignment'

    $autoSnippet = [IO.File]::ReadAllText((Join-Path $repoRoot 'snippets\AGENTS.auto.md'))
    Assert-True ($autoSnippet -match 'greenfield projects, blank repositories') 'Auto AGENTS rule triggers on greenfield work'
    Assert-True ($autoSnippet -match 'reversible, low-risk, or common implementation default') 'Auto AGENTS rule rejects reversible product defaults'
    Assert-True ($autoSnippet -match 'existing projects and explicit implementation tasks, remain conservative') 'Auto AGENTS rule preserves conservative existing-task behavior'

    $shouldAsk = [IO.File]::ReadAllText((Join-Path $repoRoot 'examples\should-ask.md'))
    $shouldNotAsk = [IO.File]::ReadAllText((Join-Path $repoRoot 'examples\should-not-ask.md'))
    Assert-True ((Get-Count $shouldAsk '(?m)^\d+\.') -ge 10) 'should-ask includes the greenfield cases and existing high-impact cases'
    Assert-True ((Get-Count $shouldNotAsk '(?m)^\d+\.') -ge 7) 'should-not-ask includes at least seven cases'
    Assert-True ($shouldAsk -match 'Blank personal task tool') 'should-ask covers the blank personal task tool'
    Assert-True ($shouldAsk -match 'Vague AI catalog idea') 'should-ask covers the vague AI catalog idea'
    Assert-True ($shouldAsk -match 'Unbounded commercial AI tool') 'should-ask covers the unbounded commercial AI tool'
    Assert-True ($shouldNotAsk -match 'README version edit') 'should-not-ask covers the explicit README edit'
    Assert-True ($shouldNotAsk -match 'Clear null bug') 'should-not-ask covers the explicit null bug'
    Assert-True ($shouldNotAsk -match '\*\*Formatting\*\*') 'should-not-ask covers formatting'

    $readme = [IO.File]::ReadAllText((Join-Path $repoRoot 'README.md'))
    Assert-True ($readme -match '## Greenfield Alignment Gate') 'README documents the greenfield gate'
    Assert-True ($readme -match 'Product goal / user goal') 'README documents product goal as the highest-priority decision'
    Assert-True ($readme -match 'Direction Alignment') 'README identifies the release as a direction-alignment calibration'

    Write-Host ''
    Write-Host "All isolated tests passed. Assertions: $passed" -ForegroundColor Green
    Write-Host 'Manual Desktop verification required' -ForegroundColor Yellow
}
finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if (-not $resolvedTestRoot.StartsWith($tempRoot + '\requirements-alignment-tests-', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean unexpected test path: $resolvedTestRoot"
        }
        $items = @(Get-ChildItem -LiteralPath $resolvedTestRoot -Force -Recurse)
        if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count -ne 0) {
            throw "Refusing to clean test tree containing a reparse point: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop
    }
}
