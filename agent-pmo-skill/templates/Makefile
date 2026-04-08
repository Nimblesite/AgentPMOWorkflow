# =============================================================================
# Standard Makefile — {{REPO_NAME}}
# Cross-platform: Linux, macOS, Windows (via GNU Make)
# All targets are language-agnostic. Add language-specific helpers below.
# =============================================================================

.PHONY: build test lint fmt clean ci setup

# -----------------------------------------------------------------------------
# OS Detection — portable commands for Linux, macOS, and Windows
# On Windows, run via GNU Make with PowerShell (e.g., make from Git Bash or
# choco install make). The $(OS) variable is set to "Windows_NT" automatically.
# -----------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
  SHELL := powershell.exe
  .SHELLFLAGS := -NoProfile -Command
  RM = Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  MKDIR = New-Item -ItemType Directory -Force
  # On Windows, HOME may not be set; use USERPROFILE
  HOME ?= $(USERPROFILE)
else
  RM = rm -rf
  MKDIR = mkdir -p
endif

# =============================================================================
# Coverage thresholds — read from `coverage-thresholds.json` at the repo root.
# See REPO-STANDARDS-SPEC §3.3 [COVERAGE-THRESHOLDS-JSON].
# DO NOT hardcode a threshold here. DO NOT read from a CI env var.
# DO NOT reference GitHub repo variables. The JSON file is the single source.
# The internal `_coverage_check` recipe (called by `_test`) parses this file
# with `jq` and asserts measured % >= threshold.
# =============================================================================
COVERAGE_THRESHOLDS_FILE := coverage-thresholds.json

# =============================================================================
# PRIMARY TARGETS — these 7 are the ENTIRE public interface. Do not add others.
#
# BANNED — never add these targets back:
#   - fmt-check       → `make lint` runs the formatter in --check mode
#   - check           → does not exist; use `make ci` or `make lint && make test`
#   - coverage        → `make test` already produces coverage
#   - coverage-check  → `make test` already enforces the threshold
#   - test-fast / test-no-coverage / test-unit → `make test` is the ONLY test target
# =============================================================================

## build: Compile/assemble all artifacts
build:
	@echo "==> Building..."
	$(MAKE) _build

## test: FAIL-FAST tests + coverage + threshold enforcement (ONLY test entry point).
##       Stops at the first failing test. Collects coverage. Asserts measured %
##       against `coverage-thresholds.json`. Exits non-zero on any failure.
##       See REPO-STANDARDS-SPEC §3 [TEST-FAIL-FAST] and §3.3 [COVERAGE-THRESHOLDS-JSON].
test:
	@echo "==> Testing (fail-fast + coverage + threshold)..."
	$(MAKE) _test

## lint: Run all linters AND check formatting in one pass.
##       Format diffs are lint failures. There is no separate `fmt-check` target.
lint:
	@echo "==> Linting (includes format check)..."
	$(MAKE) _lint

## fmt: Format all code in-place
fmt:
	@echo "==> Formatting..."
	$(MAKE) _fmt

## clean: Remove all build artifacts
clean:
	@echo "==> Cleaning..."
	$(MAKE) _clean

## ci: lint + test + build (full CI simulation)
ci: lint test build

## setup: Post-create dev environment setup (used by devcontainer)
setup:
	@echo "==> Setting up development environment..."
	$(MAKE) _setup
	@echo "==> Setup complete. Run 'make ci' to validate."

# =============================================================================
# LANGUAGE-SPECIFIC IMPLEMENTATIONS
# Override these private recipes in a language section below:
#   _build, _test, _lint, _fmt, _clean, _setup
# Plus the internal helper called by _test (do not expose as a public target):
#   _coverage_check
#
# Rules for the language sections:
#   - `_lint` MUST run the formatter in --check mode FIRST, then run linters.
#     Format diffs are lint failures. No separate `_fmt_check`.
#   - `_test` MUST use the test runner's fail-fast flag AND call `_coverage_check`
#     after the runner exits. There is no separate `coverage` or `coverage-check`
#     public target.
# For multi-language repos, chain them: _test: test-rust test-ts test-dotnet
# =============================================================================

# --- RUST ---
# Prerequisites: cargo install cargo-llvm-cov && rustup component add llvm-tools-preview
#
# _build:
# 	cargo build --release
#
# # Fail-fast: cargo test stops on first failure by default. NEVER pass --no-fail-fast.
# # _coverage_check is internal; called as the last line of _test.
# _test:
# 	rustup component add llvm-tools-preview 2>/dev/null || true
# 	cargo llvm-cov --workspace --all-targets --lcov --output-path lcov.info
# 	$(MAKE) _coverage_check
#
# # Format check FIRST (any diff = lint failure), then linters.
# _lint:
# 	cargo fmt --all --check
# 	cargo clippy --release --all-targets -- -D warnings
#
# _fmt:
# 	cargo fmt --all
#
# _clean:
# 	cargo clean
#
# # Internal helper called by _test. Reads default_threshold from
# # coverage-thresholds.json, asserts measured >= threshold.
# _coverage_check:
# 	@if [ ! -f "$(COVERAGE_THRESHOLDS_FILE)" ]; then echo "FAIL: $(COVERAGE_THRESHOLDS_FILE) not found"; exit 1; fi; \
# 	THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	LH=$$(grep '^LH:' lcov.info | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	LF=$$(grep '^LF:' lcov.info | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	if [ "$$LF" -eq 0 ]; then echo "FAIL: No lines in lcov.info"; exit 1; fi; \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $$LH/$$LF*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $$LH/$$LF*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $${THRESHOLD}%)"; \
# 	if [ "$$PCT_INT" -lt "$${THRESHOLD}" ]; then \
# 	  echo "FAIL: $${PCT}% < $${THRESHOLD}%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $${THRESHOLD}%"; \
# 	fi
#
# _setup:
# 	cargo install cargo-llvm-cov cargo-watch

# --- TYPESCRIPT/NODE ---
# Prerequisites: npm install; jest.coverage.config.js in repo root
#
# _build:
# 	npm run build
#
# # Fail-fast: Jest --bail / Vitest --bail=1. The npm "test:coverage" script MUST
# # include the bail flag (e.g. "jest --coverage --bail").
# _test:
# 	npm run test:coverage
# 	$(MAKE) _coverage_check
#
# # Format check FIRST (any diff = lint failure), then lint + typecheck.
# _lint:
# 	npm run fmt:check
# 	npm run lint
# 	npm run typecheck
#
# _fmt:
# 	npm run fmt
#
# _clean:
# 	$(RM) out dist coverage .vscode-test
#
# _coverage_check:
# 	@THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	npx c8 check-coverage --lines $$THRESHOLD
#
# _setup:
# 	npm ci

# --- PYTHON ---
# Prerequisites: pip install basilisk pytest pytest-cov ruff pyright
#
# _build:
# 	python -m build
#
# # Fail-fast: pytest -x stops on first failure (alias for --maxfail=1).
# _test:
# 	python -m pytest -x tests/ --cov=. --cov-report=lcov:lcov.info \
# 	  --cov-report=term-missing
# 	$(MAKE) _coverage_check
#
# # Order is non-negotiable (REPO-STANDARDS-SPEC §4.6 [LINT-PYTHON-BASILISK]):
# #   1. Format check (any diff = lint failure)
# #   2. Basilisk (PRIMARY linter + type checker)
# #   3. ruff (secondary lint)
# #   4. pyright (secondary type-check safety net)
# _lint:
# 	ruff format --check .
# 	basilisk lint .
# 	ruff check .
# 	pyright .
#
# _fmt:
# 	ruff format .
# 	ruff check --fix .
#
# _clean:
# 	$(RM) dist build *.egg-info htmlcov .coverage coverage.xml lcov.info
#
# _coverage_check:
# 	@THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	python -m coverage report --fail-under=$$THRESHOLD
#
# _setup:
# 	pip install -r requirements.txt

# --- DART/FLUTTER ---
# Prerequisites: brew install lcov (for genhtml, optional local viewer)
#
# _build:
# 	flutter build apk --debug || dart compile exe lib/main.dart
#
# # Fail-fast: --fail-fast stops at the first failing test.
# _test:
# 	flutter test --coverage --fail-fast
# 	$(MAKE) _coverage_check
#
# # Format check FIRST (any diff = lint failure), then analyzer.
# _lint:
# 	dart format --set-exit-if-changed .
# 	flutter analyze --fatal-infos
#
# _fmt:
# 	dart format .
#
# _clean:
# 	flutter clean || $(RM) build
#
# _coverage_check:
# 	@if [ ! -f "$(COVERAGE_THRESHOLDS_FILE)" ]; then echo "FAIL: $(COVERAGE_THRESHOLDS_FILE) not found"; exit 1; fi; \
# 	THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	LCOV_FILE="coverage/lcov.info"; \
# 	if [ ! -f "$$LCOV_FILE" ]; then echo "FAIL: $$LCOV_FILE not found"; exit 1; fi; \
# 	LH=$$(grep '^LH:' "$$LCOV_FILE" | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	LF=$$(grep '^LF:' "$$LCOV_FILE" | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	if [ "$$LF" -eq 0 ]; then echo "FAIL: No lines in lcov.info"; exit 1; fi; \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $$LH/$$LF*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $$LH/$$LF*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $${THRESHOLD}%)"; \
# 	if [ "$$PCT_INT" -lt "$${THRESHOLD}" ]; then \
# 	  echo "FAIL: $${PCT}% < $${THRESHOLD}%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $${THRESHOLD}%"; \
# 	fi
#
# _setup:
# 	flutter pub get

# --- C#/.NET ---
# Prerequisites: dotnet tool install -g dotnet-reportgenerator-globaltool
# Config: coverlet.runsettings must be in repo root
#
# _build:
# 	dotnet build --configuration Release
#
# # Fail-fast: xunit.stopOnFail=true stops at the first failing test (xUnit).
# # For NUnit/MSTest see their docs for the equivalent runsettings.
# _test:
# 	$(RM) TestResults
# 	dotnet test $$(find . -maxdepth 1 -name '*.sln' | head -1) \
# 	  --configuration Release \
# 	  --settings coverlet.runsettings \
# 	  --collect:"XPlat Code Coverage" \
# 	  --results-directory TestResults \
# 	  --verbosity normal \
# 	  -- xunit.stopOnFail=true
# 	$(MAKE) _coverage_check
#
# # Format check FIRST (CSharpier diff = lint failure), then build with -warnaserror.
# _lint:
# 	dotnet csharpier . --check
# 	dotnet build --configuration Release -warnaserror
#
# _fmt:
# 	dotnet csharpier .
#
# _clean:
# ifeq ($(OS),Windows_NT)
# 	Get-ChildItem -Recurse -Directory -Include bin,obj | Remove-Item -Recurse -Force
# else
# 	find . -type d \( -name bin -o -name obj \) -exec rm -rf {} +
# endif
#
# # Reads `coverage-thresholds.json`. For multi-project repos, iterates over
# # `.projects` and asserts each project's measured coverage >= its threshold.
# # For single-project repos, falls back to `.default_threshold`.
# _coverage_check:
# 	@if [ ! -f "$(COVERAGE_THRESHOLDS_FILE)" ]; then echo "FAIL: $(COVERAGE_THRESHOLDS_FILE) not found"; exit 1; fi; \
# 	COBERTURA=$$(find TestResults -name 'coverage.cobertura.xml' | head -1); \
# 	if [ -z "$$COBERTURA" ]; then echo "FAIL: No coverage.cobertura.xml found"; exit 1; fi; \
# 	THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	LINE_RATE=$$(grep -oP 'line-rate="\K[^"]+' "$$COBERTURA" | head -1); \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $${LINE_RATE:-0}*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $${LINE_RATE:-0}*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $${THRESHOLD}%)"; \
# 	if [ "$$PCT_INT" -lt "$${THRESHOLD}" ]; then \
# 	  echo "FAIL: $${PCT}% < $${THRESHOLD}%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $${THRESHOLD}%"; \
# 	fi
#
# _setup:
# 	dotnet restore
# 	dotnet tool restore

# --- F# ---
# Same as C#/.NET above; substitute Fantomas in _lint and _fmt:
# _lint:  dotnet fantomas . --check && dotnet build --configuration Release -warnaserror
# _fmt:   dotnet fantomas .

# --- GO ---
#
# _build:
# 	go build ./...
#
# # Fail-fast: -failfast stops at the first failing test in a package.
# _test:
# 	go test -failfast -covermode=atomic -coverprofile=coverage.out ./...
# 	go tool cover -func=coverage.out
# 	$(MAKE) _coverage_check
#
# # Format check FIRST (gofmt diff = lint failure), then linters.
# _lint:
# 	gofmt -l . | grep . && exit 1 || true
# 	golangci-lint run
#
# _fmt:
# 	gofmt -w .
# 	golangci-lint run --fix
#
# _clean:
# 	go clean ./...
# 	$(RM) coverage.out coverage.html
#
# _coverage_check:
# 	@if [ ! -f "$(COVERAGE_THRESHOLDS_FILE)" ]; then echo "FAIL: $(COVERAGE_THRESHOLDS_FILE) not found"; exit 1; fi; \
# 	THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	PCT=$$(go tool cover -func=coverage.out | awk '/^total:/{print $$3}' | tr -d '%'); \
# 	PCT_INT=$$(echo "$$PCT" | awk '{printf "%d", $$1}'); \
# 	echo "Line coverage: $${PCT}% (threshold: $${THRESHOLD}%)"; \
# 	if [ "$$PCT_INT" -lt "$${THRESHOLD}" ]; then \
# 	  echo "FAIL: $${PCT}% < $${THRESHOLD}%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $${THRESHOLD}%"; \
# 	fi
#
# _setup:
# 	go mod download
# 	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.1.6

# =============================================================================
# HELP
# =============================================================================
help:
	@echo "Targets:"
	@echo "  build  - Compile/assemble all artifacts"
	@echo "  test   - FAIL-FAST tests + coverage + threshold enforcement (ONLY test entry point)"
	@echo "  lint   - All linters AND format check (any diff = failure)"
	@echo "  fmt    - Format all code in-place"
	@echo "  clean  - Remove build artifacts"
	@echo "  ci     - lint + test + build (full CI simulation)"
	@echo "  setup  - Post-create dev environment setup"
	@echo ""
	@echo "Banned (do not add): fmt-check, check, coverage, coverage-check, test-fast, test-no-coverage"
