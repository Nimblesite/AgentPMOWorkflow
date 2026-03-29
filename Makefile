# =============================================================================
# Makefile — project_status
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

.PHONY: build test test-fsharp test-mock test-local test-e2e lint fmt fmt-check clean check ci \
        install-skill install-skill-unix install-skill-windows \
        uninstall-skill uninstall-skill-unix uninstall-skill-windows \
        website-build website-run setup help

# =============================================================================
# PRIMARY TARGETS (cross-platform — dotnet, npx, gh are already portable)
# =============================================================================

build:
	@echo "==> Building dashboard report..."
	dotnet fsi dashboard/repo-report.fsx

test: test-fsharp test-e2e

test-fsharp: test-mock

test-mock:
	@echo "==> Running F# mock fixture tests (generates report)..."
	dotnet fsi dashboard/test-report.fsx

test-local: build test-e2e
	@echo "==> Local tests passed (report generated from config.json, validated by Playwright)"

test-e2e:
	@echo "==> Running Playwright E2E tests..."
	cd dashboard && npx playwright test

lint:
	@echo "==> Linting..."
	cd dashboard && npx playwright test --list

fmt:
	@echo "==> Formatting..."
	@echo "    No auto-formatter configured for F# scripts."

fmt-check:
	@echo "==> Checking format..."
	@echo "    No format check configured for F# scripts."

clean:
	@echo "==> Cleaning..."
	$(RM) dashboard/test-results
	$(RM) dashboard/playwright-report

check: lint test

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
# SKILL MANAGEMENT (platform-specific: symlinks vs junctions)
# =============================================================================

ifeq ($(OS),Windows_NT)
install-skill: install-skill-windows
uninstall-skill: uninstall-skill-windows
else
install-skill: install-skill-unix
uninstall-skill: uninstall-skill-unix
endif

# --- Unix (macOS / Linux) ---
install-skill-unix:
	@echo "==> Install Claude Code Skill Globally..."
	@$(MKDIR) "$(HOME)/.claude/skills"
	@if [ -L "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		echo "    Removing existing symlink..."; \
		$(RMFILE) "$(HOME)/.claude/skills/enforce-repo-standards"; \
	elif [ -d "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		echo "ERROR: $(HOME)/.claude/skills/enforce-repo-standards exists and is not a symlink. Remove it manually."; \
		exit 1; \
	fi
	@ln -s "$$(pwd)/enforce-repo-standards" "$(HOME)/.claude/skills/enforce-repo-standards"
	@echo "    $(HOME)/.claude/skills/enforce-repo-standards -> $$(pwd)/enforce-repo-standards"
	@echo "==> Done. Skill available globally as /enforce-repo-standards"

uninstall-skill-unix:
	@echo "==> Removing enforce-repo-standards skill..."
	@if [ -L "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		$(RMFILE) "$(HOME)/.claude/skills/enforce-repo-standards"; \
		echo "    Removed."; \
	else \
		echo "    Nothing to remove."; \
	fi
	@echo "==> Done."

# --- Windows (PowerShell) ---
install-skill-windows:
	@echo "==> Install Claude Code Skill Globally (Windows)..."
	$(MKDIR) "$(HOME)/.claude/skills" | Out-Null
	$$skillPath = "$(HOME)/.claude/skills/enforce-repo-standards"; \
	if (Test-Path $$skillPath) { Remove-Item $$skillPath -Recurse -Force }; \
	New-Item -ItemType Junction -Path $$skillPath -Target "$(CURDIR)/enforce-repo-standards" | Out-Null; \
	Write-Host "    $$skillPath -> $(CURDIR)/enforce-repo-standards"; \
	Write-Host "==> Done. Skill available globally as /enforce-repo-standards"

uninstall-skill-windows:
	@echo "==> Removing enforce-repo-standards skill (Windows)..."
	$$skillPath = "$(HOME)/.claude/skills/enforce-repo-standards"; \
	if (Test-Path $$skillPath) { Remove-Item $$skillPath -Recurse -Force; Write-Host "    Removed." } \
	else { Write-Host "    Nothing to remove." }; \
	Write-Host "==> Done."

# =============================================================================
# HELP
# =============================================================================
help:
	@echo "Available targets:"
	@echo "  build            - Generate the HTML dashboard report"
	@echo "  test             - Run all tests (F# + Playwright E2E)"
	@echo "  test-fsharp      - Run F# tests (alias for test-mock)"
	@echo "  test-mock        - Run F# mock fixture tests (generates report for E2E)"
	@echo "  test-local       - Generate report from config.json + run Playwright E2E"
	@echo "  test-e2e         - Run Playwright E2E tests"
	@echo "  lint             - Validate Playwright test configuration"
	@echo "  fmt              - Format code (no-op for F# scripts)"
	@echo "  fmt-check        - Check formatting (no-op for F# scripts)"
	@echo "  clean            - Remove test artifacts"
	@echo "  check            - lint + test (pre-commit)"
	@echo "  ci               - lint + test + build (full CI)"
	@echo "  setup            - Install dependencies + configure (auto-detects OS)"
	@echo "  website-build    - Build the HTML dashboard report"
	@echo "  website-run      - Serve the dashboard locally on port 8080"
	@echo "  install-skill    - Install Claude Code Skill Globally"
	@echo "  uninstall-skill  - Remove the global skill symlink"
