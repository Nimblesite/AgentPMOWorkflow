# =============================================================================
# Makefile — AgentPMOWorkflow
# Cross-platform: Linux, macOS, Windows (via GNU Make)
# =============================================================================

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
  SHELL := powershell.exe
  .SHELLFLAGS := -NoProfile -Command
  RM = Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  MKDIR = New-Item -ItemType Directory -Force
  RMFILE = Remove-Item -Force -ErrorAction SilentlyContinue
  # On Windows, HOME may not be set; use USERPROFILE
  HOME ?= $(USERPROFILE)
else
  RM = rm -rf
  MKDIR = mkdir -p
  RMFILE = rm -f
endif

# Public targets — the ones users invoke directly.
.PHONY: build dashboard test lint fmt clean ci setup help \
        website-build website-run \
        install-skill-claude   uninstall-skill-claude \
        install-skill-codex    uninstall-skill-codex \
        install-skill-copilot  uninstall-skill-copilot \
        install-skill-cline    uninstall-skill-cline \
        install-skill-roo      uninstall-skill-roo \
        install-skill-opencode uninstall-skill-opencode \
        install-skill-all      uninstall-skill-all

# Private helpers — internal plumbing, underscore-prefixed so tooling hides them.
.PHONY: _test_fsharp _test_e2e \
        _install-skill-claude-unix   _install-skill-claude-windows \
        _uninstall-skill-claude-unix   _uninstall-skill-claude-windows \
        _install-skill-codex-unix    _install-skill-codex-windows \
        _uninstall-skill-codex-unix    _uninstall-skill-codex-windows \
        _install-skill-copilot-unix  _install-skill-copilot-windows \
        _uninstall-skill-copilot-unix  _uninstall-skill-copilot-windows \
        _install-skill-cline-unix    _install-skill-cline-windows \
        _uninstall-skill-cline-unix    _uninstall-skill-cline-windows \
        _install-skill-roo-unix      _install-skill-roo-windows \
        _uninstall-skill-roo-unix      _uninstall-skill-roo-windows \
        _install-skill-opencode-unix _install-skill-opencode-windows \
        _uninstall-skill-opencode-unix _uninstall-skill-opencode-windows

# =============================================================================
# PRIMARY TARGETS — exactly 7 (REPO-STANDARDS-SPEC §1.1 [MAKE-TARGETS]):
#   build, test, lint, fmt, clean, ci, setup
#
# Internal helpers (private, underscore-prefixed) chain inside the public targets.
# =============================================================================

build:
	@echo "==> Building dashboard report..."
	dotnet fsi dashboard/repo-report.fsx

dashboard:
	@echo "==> Refreshing dashboard..."
	@dotnet fsi dashboard/repo-report.fsx
	@echo "==> Done. Report at dashboard/repo-report.html"

# test: ONLY public test target. Runs F# mock fixture tests (which generate the
# report HTML), then Playwright E2E tests against the generated HTML.
# Both stages exit non-zero on the first failure.
test: _test_fsharp _test_e2e

_test_fsharp:
	@echo "==> Running F# mock fixture tests (fail-fast; generates report)..."
	dotnet fsi dashboard/test-report.fsx

_test_e2e:
	@echo "==> Running Playwright E2E tests (fail-fast)..."
	cd dashboard && npx playwright test --max-failures=1

# lint: validates Playwright test config. F# scripts have no formatter, so the
# format-check step is a no-op. If a formatter ever lands, prepend its --check
# invocation HERE — never as a separate `fmt-check` target.
lint:
	@echo "==> Linting (F# format check is a no-op; no formatter for fsx)..."
	cd dashboard && npx playwright test --list

fmt:
	@echo "==> Formatting..."
	@echo "    No auto-formatter configured for F# scripts."

clean:
	@echo "==> Cleaning..."
	$(RM) dashboard/test-results
	$(RM) dashboard/playwright-report

ci: lint test build

# =============================================================================
# SETUP (auto-detects OS)
# =============================================================================

setup:
ifeq ($(OS),Windows_NT)
	@echo "==> Running Windows setup (PowerShell)..."
	powershell -ExecutionPolicy Bypass -File setup/setup-windows.ps1
else
	@echo "==> Running setup..."
	bash setup/setup-macos-linux.sh
endif

# =============================================================================
# WEBSITE (cross-platform — npx is portable)
# =============================================================================

website-build:
	@echo "==> Building website..."
	cd website && npx @11ty/eleventy

website-run:
	@echo "==> Starting local dev server..."
	cd website && npx @11ty/eleventy --serve

# =============================================================================
# SKILL MANAGEMENT (platform-specific)
# =============================================================================

# Shared install helper — usage: $(call _install_skill_unix,LABEL,DEST_DIR)
# Copies agent-pmo-skill/SKILL.md → DEST_DIR/agent-pmo/SKILL.md with STANDARDS_REPO substituted.
define _install_skill_unix
	@echo "==> Installing agent-pmo skill for $(1)..."
	@rm -rf "$(2)/agent-pmo"
	@mkdir -p "$(2)/agent-pmo"
	@sed 's|{{STANDARDS_REPO}}|$(CURDIR)|g' \
		agent-pmo-skill/SKILL.md > "$(2)/agent-pmo/SKILL.md"
	@echo "    Installed to $(2)/agent-pmo"
	@echo "    STANDARDS_REPO = $(CURDIR)"
	@echo "==> Done."
endef

define _uninstall_skill_unix
	@echo "==> Removing agent-pmo skill for $(1)..."
	@if [ -d "$(2)/agent-pmo" ]; then \
		rm -rf "$(2)/agent-pmo"; \
		echo "    Removed."; \
	else \
		echo "    Nothing to remove."; \
	fi
	@echo "==> Done."
endef

define _install_skill_windows
	@echo "==> Installing agent-pmo skill for $(1) (Windows)..."
	$$dest = "$(2)/agent-pmo"; \
	if (Test-Path $$dest) { Remove-Item $$dest -Recurse -Force }; \
	New-Item -ItemType Directory -Path $$dest -Force | Out-Null; \
	(Get-Content "$(CURDIR)/agent-pmo-skill/SKILL.md") -replace '\{\{STANDARDS_REPO\}\}', '$(CURDIR)' | \
		Set-Content "$$dest/SKILL.md"; \
	Write-Host "    Installed to $$dest"; \
	Write-Host "==> Done."
endef

define _uninstall_skill_windows
	@echo "==> Removing agent-pmo skill for $(1) (Windows)..."
	$$dest = "$(2)/agent-pmo"; \
	if (Test-Path $$dest) { Remove-Item $$dest -Recurse -Force; Write-Host "    Removed." } \
	else { Write-Host "    Nothing to remove." }; \
	Write-Host "==> Done."
endef

# =============================================================================
# Per-agent skill directories
# =============================================================================
SKILL_DIR_CLAUDE   = $(HOME)/.claude/skills
SKILL_DIR_CODEX    = $(HOME)/.agents/skills
SKILL_DIR_COPILOT  = $(HOME)/.copilot/skills
SKILL_DIR_CLINE    = $(HOME)/.cline/skills
SKILL_DIR_ROO      = $(HOME)/.roo/skills
SKILL_DIR_OPENCODE = $(HOME)/.config/opencode/skills

# =============================================================================
# CLAUDE CODE — ~/.claude/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-claude: _install-skill-claude-windows
uninstall-skill-claude: _uninstall-skill-claude-windows
else
install-skill-claude: _install-skill-claude-unix
uninstall-skill-claude: _uninstall-skill-claude-unix
endif

_install-skill-claude-unix:
	$(call _install_skill_unix,Claude Code,$(SKILL_DIR_CLAUDE))

_uninstall-skill-claude-unix:
	$(call _uninstall_skill_unix,Claude Code,$(SKILL_DIR_CLAUDE))

_install-skill-claude-windows:
	$(call _install_skill_windows,Claude Code,$(SKILL_DIR_CLAUDE))

_uninstall-skill-claude-windows:
	$(call _uninstall_skill_windows,Claude Code,$(SKILL_DIR_CLAUDE))

# =============================================================================
# OPENAI CODEX — ~/.agents/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-codex: _install-skill-codex-windows
uninstall-skill-codex: _uninstall-skill-codex-windows
else
install-skill-codex: _install-skill-codex-unix
uninstall-skill-codex: _uninstall-skill-codex-unix
endif

_install-skill-codex-unix:
	$(call _install_skill_unix,OpenAI Codex,$(SKILL_DIR_CODEX))

_uninstall-skill-codex-unix:
	$(call _uninstall_skill_unix,OpenAI Codex,$(SKILL_DIR_CODEX))

_install-skill-codex-windows:
	$(call _install_skill_windows,OpenAI Codex,$(SKILL_DIR_CODEX))

_uninstall-skill-codex-windows:
	$(call _uninstall_skill_windows,OpenAI Codex,$(SKILL_DIR_CODEX))

# =============================================================================
# GITHUB COPILOT — ~/.copilot/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-copilot: _install-skill-copilot-windows
uninstall-skill-copilot: _uninstall-skill-copilot-windows
else
install-skill-copilot: _install-skill-copilot-unix
uninstall-skill-copilot: _uninstall-skill-copilot-unix
endif

_install-skill-copilot-unix:
	$(call _install_skill_unix,GitHub Copilot,$(SKILL_DIR_COPILOT))

_uninstall-skill-copilot-unix:
	$(call _uninstall_skill_unix,GitHub Copilot,$(SKILL_DIR_COPILOT))

_install-skill-copilot-windows:
	$(call _install_skill_windows,GitHub Copilot,$(SKILL_DIR_COPILOT))

_uninstall-skill-copilot-windows:
	$(call _uninstall_skill_windows,GitHub Copilot,$(SKILL_DIR_COPILOT))

# =============================================================================
# CLINE — ~/.cline/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-cline: _install-skill-cline-windows
uninstall-skill-cline: _uninstall-skill-cline-windows
else
install-skill-cline: _install-skill-cline-unix
uninstall-skill-cline: _uninstall-skill-cline-unix
endif

_install-skill-cline-unix:
	$(call _install_skill_unix,Cline,$(SKILL_DIR_CLINE))

_uninstall-skill-cline-unix:
	$(call _uninstall_skill_unix,Cline,$(SKILL_DIR_CLINE))

_install-skill-cline-windows:
	$(call _install_skill_windows,Cline,$(SKILL_DIR_CLINE))

_uninstall-skill-cline-windows:
	$(call _uninstall_skill_windows,Cline,$(SKILL_DIR_CLINE))

# =============================================================================
# ROO CODE — ~/.roo/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-roo: _install-skill-roo-windows
uninstall-skill-roo: _uninstall-skill-roo-windows
else
install-skill-roo: _install-skill-roo-unix
uninstall-skill-roo: _uninstall-skill-roo-unix
endif

_install-skill-roo-unix:
	$(call _install_skill_unix,Roo Code,$(SKILL_DIR_ROO))

_uninstall-skill-roo-unix:
	$(call _uninstall_skill_unix,Roo Code,$(SKILL_DIR_ROO))

_install-skill-roo-windows:
	$(call _install_skill_windows,Roo Code,$(SKILL_DIR_ROO))

_uninstall-skill-roo-windows:
	$(call _uninstall_skill_windows,Roo Code,$(SKILL_DIR_ROO))

# =============================================================================
# OPENCODE — ~/.config/opencode/skills/
# =============================================================================
ifeq ($(OS),Windows_NT)
install-skill-opencode: _install-skill-opencode-windows
uninstall-skill-opencode: _uninstall-skill-opencode-windows
else
install-skill-opencode: _install-skill-opencode-unix
uninstall-skill-opencode: _uninstall-skill-opencode-unix
endif

_install-skill-opencode-unix:
	$(call _install_skill_unix,OpenCode,$(SKILL_DIR_OPENCODE))

_uninstall-skill-opencode-unix:
	$(call _uninstall_skill_unix,OpenCode,$(SKILL_DIR_OPENCODE))

_install-skill-opencode-windows:
	$(call _install_skill_windows,OpenCode,$(SKILL_DIR_OPENCODE))

_uninstall-skill-opencode-windows:
	$(call _uninstall_skill_windows,OpenCode,$(SKILL_DIR_OPENCODE))

# =============================================================================
# ALL AGENTS — install/uninstall in one shot
# =============================================================================
install-skill-all: install-skill-claude install-skill-codex install-skill-copilot \
                   install-skill-cline install-skill-roo install-skill-opencode

uninstall-skill-all: uninstall-skill-claude uninstall-skill-codex uninstall-skill-copilot \
                     uninstall-skill-cline uninstall-skill-roo uninstall-skill-opencode

# =============================================================================
# HELP
# =============================================================================
help:
	@echo "Standard targets (REPO-STANDARDS-SPEC §1.1 [MAKE-TARGETS]):"
	@echo "  build  - Generate the HTML dashboard report"
	@echo "  test   - F# fixture tests + Playwright E2E (fail-fast). ONLY test entry point."
	@echo "  lint   - Validate Playwright test config (F# format check is a no-op)"
	@echo "  fmt    - Format code (no-op for F# scripts)"
	@echo "  clean  - Remove test artifacts"
	@echo "  ci     - lint + test + build (full CI simulation)"
	@echo "  setup  - Install dependencies + configure (auto-detects OS)"
	@echo ""
	@echo "Repo-specific helpers:"
	@echo "  dashboard              - Refresh the dashboard manually"
	@echo "  website-build          - Build the website via 11ty"
	@echo "  website-run            - Serve the website locally with 11ty"
	@echo "  install-skill-claude   - Install agent-pmo skill for Claude Code  (~/.claude/skills/)"
	@echo "  install-skill-codex    - Install agent-pmo skill for OpenAI Codex (~/.agents/skills/)"
	@echo "  install-skill-copilot  - Install agent-pmo skill for GitHub Copilot (~/.copilot/skills/)"
	@echo "  install-skill-cline    - Install agent-pmo skill for Cline         (~/.cline/skills/)"
	@echo "  install-skill-roo      - Install agent-pmo skill for Roo Code      (~/.roo/skills/)"
	@echo "  install-skill-opencode - Install agent-pmo skill for OpenCode       (~/.config/opencode/skills/)"
	@echo "  install-skill-all      - Install for all agents at once"
	@echo "  uninstall-skill-claude   - Remove agent-pmo skill for Claude Code"
	@echo "  uninstall-skill-codex    - Remove agent-pmo skill for OpenAI Codex"
	@echo "  uninstall-skill-copilot  - Remove agent-pmo skill for GitHub Copilot"
	@echo "  uninstall-skill-cline    - Remove agent-pmo skill for Cline"
	@echo "  uninstall-skill-roo      - Remove agent-pmo skill for Roo Code"
	@echo "  uninstall-skill-opencode - Remove agent-pmo skill for OpenCode"
	@echo "  uninstall-skill-all      - Remove for all agents at once"
