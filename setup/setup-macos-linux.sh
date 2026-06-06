#!/usr/bin/env bash
# =============================================================================
#  Agent PMO — Setup Script (macOS / Linux)
#  https://github.com/Nimblesite/AgentPMOWorkflow
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[agent-pmo]${RESET} $*"; }
success() { echo -e "${GREEN}[agent-pmo] ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}[agent-pmo] ⚠${RESET} $*"; }
error()   { echo -e "${RED}[agent-pmo] ✗${RESET} $*" >&2; exit 1; }

# Resolve the repo root from the script location (this file lives in setup/, so
# the repo is its parent dir). When piped via `curl | bash` there is no script
# file and BASH_SOURCE is unset — guard against that under `set -u`.
SCRIPT_SRC="${BASH_SOURCE[0]:-}"
if [[ -z "$SCRIPT_SRC" ]]; then
  error "This script must be run from a cloned repo, not piped from curl.
       git clone https://github.com/Nimblesite/AgentPMOWorkflow.git
       cd AgentPMOWorkflow && make setup"
fi
REPO_DIR="$(cd "$(dirname "$SCRIPT_SRC")/.." && pwd)"

# Sanity check: the dashboard script must exist under the resolved repo root.
if [[ ! -f "${REPO_DIR}/dashboard/repo-report.fsx" ]]; then
  error "Could not find the repo at ${REPO_DIR}.
       Run this from a cloned repo via: make setup"
fi

case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      error "Unsupported OS: $(uname -s). Use setup-windows.ps1 for Windows." ;;
esac

info "OS: ${BOLD}${OS}${RESET}  Repo: ${REPO_DIR}"

# ── 1. .NET SDK ──────────────────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
  info "Installing .NET SDK..."
  if [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      brew install --quiet dotnet || brew upgrade --quiet dotnet || true
    else
      curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 --install-dir "$HOME/.dotnet"
      export PATH="$HOME/.dotnet:$PATH"
    fi
  else
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq && sudo apt-get install -y dotnet-sdk-8.0 || {
        curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 --install-dir "$HOME/.dotnet"
        export PATH="$HOME/.dotnet:$PATH"
      }
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y dotnet-sdk-8.0
    else
      curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 --install-dir "$HOME/.dotnet"
      export PATH="$HOME/.dotnet:$PATH"
    fi
  fi
  # Ensure PATH includes .dotnet
  command -v dotnet &>/dev/null || export PATH="$HOME/.dotnet:$PATH"
  command -v dotnet &>/dev/null || error ".NET SDK install failed. See https://dot.net"
  success ".NET SDK installed: $(dotnet --version)"
else
  success ".NET SDK: $(dotnet --version)"
fi

# ── 2. gh CLI ────────────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  info "Installing gh CLI..."
  if [[ "$OS" == "macos" ]]; then
    command -v brew &>/dev/null || error "Homebrew required for gh on macOS. See https://cli.github.com"
    brew install --quiet gh || brew upgrade --quiet gh || true
  else
    if command -v apt-get &>/dev/null; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y gh
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y gh
    else
      warn "Install gh manually: https://cli.github.com"
    fi
  fi
  command -v gh &>/dev/null || error "gh CLI install failed. See https://cli.github.com"
  success "gh CLI: $(gh --version | head -1)"
else
  success "gh CLI: $(gh --version | head -1)"
fi

# ── 3. gh auth check ────────────────────────────────────────────────────────
if ! gh auth status &>/dev/null 2>&1; then
  warn "gh not authenticated. Run: gh auth login"
else
  success "gh authenticated"
fi

# ── 4. Config ────────────────────────────────────────────────────────────────
CONFIG_FILE="${REPO_DIR}/dashboard/config.json"
EXAMPLE_FILE="${REPO_DIR}/dashboard/config.example.json"

if [[ ! -f "$CONFIG_FILE" ]] && [[ -f "$EXAMPLE_FILE" ]]; then
  cp "$EXAMPLE_FILE" "$CONFIG_FILE"
  success "Created dashboard/config.json"
elif [[ -f "$CONFIG_FILE" ]]; then
  info "dashboard/config.json exists — skipping"
fi

# ── 5. Generate report ──────────────────────────────────────────────────────
REPORT_PATH="${REPO_DIR}/dashboard/repo-report.html"
info "Generating dashboard..."
if dotnet fsi "${REPO_DIR}/dashboard/repo-report.fsx" 2>"${REPO_DIR}/dashboard/repo-report-debug.log"; then
  success "Report: ${REPORT_PATH}"
else
  warn "Report had issues — see dashboard/repo-report-debug.log"
fi

# ── 6. Schedule auto-refresh ────────────────────────────────────────────────
DOTNET_BIN="$(command -v dotnet)"

if [[ "$OS" == "macos" ]]; then
  PLIST_NAME="com.agentpmo.repo-report"
  PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"
  LOG_DIR="${HOME}/Library/Logs/AgentPMO"
  mkdir -p "$LOG_DIR"

  cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${DOTNET_BIN}</string>
        <string>fsi</string>
        <string>${REPO_DIR}/dashboard/repo-report.fsx</string>
    </array>
    <key>WorkingDirectory</key><string>${REPO_DIR}</string>
    <key>StartInterval</key><integer>180</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>${LOG_DIR}/repo-report.log</string>
    <key>StandardErrorPath</key><string>${LOG_DIR}/repo-report-debug.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${HOME}/.dotnet</string>
    </dict>
</dict>
</plist>
PLIST

  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
  success "launchd job: ${PLIST_NAME} (every 3 min)"
else
  CRON_MARKER="# agent-pmo-dashboard"
  CRON_ENTRY="*/3 * * * * cd '${REPO_DIR}' && ${DOTNET_BIN} fsi '${REPO_DIR}/dashboard/repo-report.fsx' >> '${REPO_DIR}/dashboard/repo-report.log' 2>> '${REPO_DIR}/dashboard/repo-report-debug.log' ${CRON_MARKER}"
  ( crontab -l 2>/dev/null | grep -v "$CRON_MARKER"; echo "$CRON_ENTRY" ) | crontab -
  success "Cron job installed (every 3 min)"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
success "Agent PMO is ready!"
echo "  Dashboard: ${REPORT_PATH}"
echo "  Refresh:   every 3 minutes"
echo ""
echo "  Next: open ${REPORT_PATH}"
echo "  Docs: https://nimblesite.github.io/AgentPMOWorkflow"
echo ""
