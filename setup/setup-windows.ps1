# =============================================================================
#  Agent PMO — Setup Script (Windows)
#  https://github.com/Nimblesite/AgentPMOWorkflow
# =============================================================================

$ErrorActionPreference = "Stop"

function Info($msg)    { Write-Host "[agent-pmo] $msg" -ForegroundColor Cyan }
function Success($msg) { Write-Host "[agent-pmo] ✓ $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[agent-pmo] ⚠ $msg" -ForegroundColor Yellow }
function Fail($msg)    { Write-Host "[agent-pmo] ✗ $msg" -ForegroundColor Red; exit 1 }

# Resolve the repo root from the script location (this file lives in setup\, so
# the repo is its parent dir). When piped via `irm | iex` there is no script
# file, so $PSCommandPath is null — bail out with clone instructions.
if (-not $PSCommandPath) {
    Fail "This script must be run from a cloned repo, not piped from the web.`n       git clone https://github.com/Nimblesite/AgentPMOWorkflow.git`n       cd AgentPMOWorkflow; make setup"
}
$RepoDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not (Test-Path (Join-Path $RepoDir "dashboard\repo-report.fsx"))) {
    Fail "Could not find the repo at $RepoDir. Run from a cloned repo via: make setup"
}
Info "Repo: $RepoDir"

# ── 1. .NET SDK ──────────────────────────────────────────────────────────────
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Info "Installing .NET SDK..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install dotnet-sdk -y
    } else {
        $installer = Join-Path $env:TEMP "dotnet-install.ps1"
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
        & $installer -Channel 8.0
        Remove-Item $installer -Force
        $env:PATH = "$env:LOCALAPPDATA\Microsoft\dotnet;$env:PATH"
    }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        # Refresh PATH from registry
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Fail ".NET SDK install failed. Download from https://dot.net"
    }
    Success "Installed .NET SDK: $(dotnet --version)"
} else {
    Success ".NET SDK: $(dotnet --version)"
}

# ── 2. gh CLI ────────────────────────────────────────────────────────────────
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Info "Installing gh CLI..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install gh -y
    } else {
        Fail "Install gh CLI manually: https://cli.github.com"
    }
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Fail "gh CLI install failed. See https://cli.github.com"
    }
    Success "gh CLI: $(gh --version | Select-Object -First 1)"
} else {
    Success "gh CLI: $(gh --version | Select-Object -First 1)"
}

# ── 3. gh auth check ────────────────────────────────────────────────────────
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Warn "gh not authenticated. Run: gh auth login"
} else {
    Success "gh authenticated"
}

# ── 4. Config ────────────────────────────────────────────────────────────────
$ConfigFile = Join-Path $RepoDir "dashboard\config.json"
$ExampleFile = Join-Path $RepoDir "dashboard\config.example.json"

if (-not (Test-Path $ConfigFile) -and (Test-Path $ExampleFile)) {
    Copy-Item $ExampleFile $ConfigFile
    Success "Created dashboard/config.json"
} elseif (Test-Path $ConfigFile) {
    Info "dashboard/config.json exists — skipping"
}

# ── 5. Generate report ──────────────────────────────────────────────────────
$ReportPath = Join-Path $RepoDir "dashboard\repo-report.html"
$DebugLog = Join-Path $RepoDir "dashboard\repo-report-debug.log"
Info "Generating dashboard..."
try {
    dotnet fsi (Join-Path $RepoDir "dashboard\repo-report.fsx") 2> $DebugLog
    Success "Report: $ReportPath"
} catch {
    Warn "Report had issues — see dashboard/repo-report-debug.log"
}

# ── 6. Schedule auto-refresh (Task Scheduler) ───────────────────────────────
$TaskName = "AgentPMO-RepoReport"
Info "Setting up scheduled task (every 3 minutes)..."

$action = New-ScheduledTaskAction `
    -Execute (Get-Command dotnet).Source `
    -Argument "fsi `"$(Join-Path $RepoDir 'dashboard\repo-report.fsx')`"" `
    -WorkingDirectory $RepoDir

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 3) `
    -RepetitionDuration (New-TimeSpan -Days 365)

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Description "Agent PMO dashboard refresh (every 3 min)" | Out-Null
    Success "Scheduled task: $TaskName (every 3 min)"
} catch {
    Warn "Could not create scheduled task. Run as admin, or set up manually."
    Warn "Manual: dotnet fsi dashboard\repo-report.fsx"
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Success "Agent PMO is ready!"
Write-Host "  Dashboard: $ReportPath"
Write-Host "  Refresh:   every 3 minutes"
Write-Host ""
Write-Host "  Next: Start-Process `"$ReportPath`""
Write-Host "  Docs: https://nimblesite.github.io/AgentPMOWorkflow"
Write-Host ""
