# =============================================================================
# Makefile — project_status
# =============================================================================

.PHONY: build test test-fsharp test-mock test-local test-e2e lint fmt fmt-check clean check ci \
        install-skill uninstall-skill help

# =============================================================================
# PRIMARY TARGETS
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
	rm -rf dashboard/test-results/
	rm -rf dashboard/playwright-report/

check: lint test

ci: lint test build

# =============================================================================
# SKILL MANAGEMENT
# =============================================================================

install-skill:
	@echo "==> Install Claude Code Skill Globally..."
	@mkdir -p "$(HOME)/.claude/skills"
	@if [ -L "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		echo "    Removing existing symlink..."; \
		rm "$(HOME)/.claude/skills/enforce-repo-standards"; \
	elif [ -d "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		echo "ERROR: $(HOME)/.claude/skills/enforce-repo-standards exists and is not a symlink. Remove it manually."; \
		exit 1; \
	fi
	@ln -s "$$(pwd)/enforce-repo-standards" "$(HOME)/.claude/skills/enforce-repo-standards"
	@echo "    $(HOME)/.claude/skills/enforce-repo-standards -> $$(pwd)/enforce-repo-standards"
	@echo "==> Done. Skill available globally as /enforce-repo-standards"

uninstall-skill:
	@echo "==> Removing enforce-repo-standards skill..."
	@if [ -L "$(HOME)/.claude/skills/enforce-repo-standards" ]; then \
		rm "$(HOME)/.claude/skills/enforce-repo-standards"; \
		echo "    Removed."; \
	else \
		echo "    Nothing to remove."; \
	fi
	@echo "==> Done."

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
	@echo "  install-skill    - Install Claude Code Skill Globally"
	@echo "  uninstall-skill  - Remove the global skill symlink"
