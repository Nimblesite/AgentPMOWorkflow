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

.PHONY: build dashboard test _test_fsharp _test_e2e lint fmt clean ci \
        install-skill-claude install-skill-claude-unix install-skill-claude-windows \
        uninstall-skill-claude uninstall-skill-claude-unix uninstall-skill-claude-windows \
        website-build website-run setup help

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
	powershell -ExecutionPolicy Bypass -File setup/setup.ps1
else
	@echo "==> Running setup..."
	bash setup/setup.sh
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

SKILL_DIR = $(HOME)/.claude/skills/agent-pmo

ifeq ($(OS),Windows_NT)
install-skill-claude: install-skill-claude-windows
uninstall-skill-claude: uninstall-skill-claude-windows
else
install-skill-claude: install-skill-claude-unix
uninstall-skill-claude: uninstall-skill-claude-unix
endif

# --- Unix (macOS / Linux) ---
install-skill-claude-unix:
	@echo "==> Install agent-pmo skill for Claude Code..."
	@rm -rf "$(SKILL_DIR)"
	@mkdir -p "$(SKILL_DIR)"
	@sed 's|{{STANDARDS_REPO}}|$(CURDIR)|g' \
		agent-pmo-skill/SKILL.md > "$(SKILL_DIR)/SKILL.md"
	@echo "    Installed to $(SKILL_DIR)"
	@echo "    STANDARDS_REPO = $(CURDIR)"
	@echo "==> Done. Skill available globally as /agent-pmo"

uninstall-skill-claude-unix:
	@echo "==> Removing agent-pmo skill..."
	@if [ -d "$(SKILL_DIR)" ]; then \
		rm -rf "$(SKILL_DIR)"; \
		echo "    Removed."; \
	else \
		echo "    Nothing to remove."; \
	fi
	@echo "==> Done."

# --- Windows (PowerShell) ---
install-skill-claude-windows:
	@echo "==> Install agent-pmo skill for Claude Code (Windows)..."
	$$skillPath = "$(SKILL_DIR)"; \
	if (Test-Path $$skillPath) { Remove-Item $$skillPath -Recurse -Force }; \
	New-Item -ItemType Directory -Path $$skillPath -Force | Out-Null; \
	(Get-Content "$(CURDIR)/agent-pmo-skill/SKILL.md") -replace '\{\{STANDARDS_REPO\}\}', '$(CURDIR)' | \
		Set-Content "$$skillPath/SKILL.md"; \
	Write-Host "    Installed to $$skillPath"; \
	Write-Host "    STANDARDS_REPO = $(CURDIR)"; \
	Write-Host "==> Done. Skill available globally as /agent-pmo"

uninstall-skill-claude-windows:
	@echo "==> Removing agent-pmo skill (Windows)..."
	$$skillPath = "$(SKILL_DIR)"; \
	if (Test-Path $$skillPath) { Remove-Item $$skillPath -Recurse -Force; Write-Host "    Removed." } \
	else { Write-Host "    Nothing to remove." }; \
	Write-Host "==> Done."

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
	@echo "  install-skill-claude   - Install agent-pmo skill for Claude Code"
	@echo "  uninstall-skill-claude - Remove the agent-pmo skill"
