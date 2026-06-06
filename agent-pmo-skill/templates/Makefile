# =============================================================================
# Standard Makefile — {{REPO_NAME}}
# Cross-platform: Linux, macOS, Windows (via GNU Make)
# All targets are language-agnostic. Fill in language-specific commands below.
# =============================================================================

.PHONY: build test lint fmt clean ci setup

# ---------------------------------------------------------------------------
# OS Detection
# ---------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
  SHELL := powershell.exe
  .SHELLFLAGS := -NoProfile -Command
  RM = Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  MKDIR = New-Item -ItemType Directory -Force
  HOME ?= $(USERPROFILE)
else
  RM = rm -rf
  MKDIR = mkdir -p
endif

# ---------------------------------------------------------------------------
# Coverage — single source of truth is coverage-thresholds.json
# See REPO-STANDARDS-SPEC [COVERAGE-THRESHOLDS-JSON].
# ---------------------------------------------------------------------------
COVERAGE_THRESHOLDS_FILE := coverage-thresholds.json

# =============================================================================
# Standard Targets
#
# Canonical portfolio-wide names. Keep only the targets that APPLY to this repo
# and delete the rest — do not ship a hollow no-op target (e.g. an empty `build`
# on a docs-only repo) just to "have all 7". When a target is present it MUST use
# the name below — never a synonym. Also trim .PHONY to match.
# Do NOT add extra public targets here — put them in the Repo-Specific
# Targets section at the bottom of this file.
# See REPO-STANDARDS-SPEC [MAKE-TARGETS].
# =============================================================================

## build: Compile/assemble all artifacts
build:
	@echo "==> Building..."
	# TODO: add build command (see language sections below)

## test: Fail-fast tests + coverage + threshold enforcement.
##       See REPO-STANDARDS-SPEC [TEST-RULES] and [COVERAGE-THRESHOLDS-JSON].
test:
	@echo "==> Testing (fail-fast + coverage + threshold)..."
	# TODO: add test command + call $(MAKE) _coverage_check (see language sections below)

## lint: Run all linters/analyzers (read-only). Does NOT format.
lint:
	@echo "==> Linting..."
	# TODO: add lint command (see language sections below)

## fmt: Format all code in-place. Pass CHECK=1 for read-only check (CI use).
fmt:
	@echo "==> Formatting$(if $(CHECK), (check mode),)..."
	# TODO: add fmt command, branching on $(CHECK) if needed (see language sections below)

## clean: Remove all build artifacts
clean:
	@echo "==> Cleaning..."
	# TODO: add clean command (see language sections below)

## ci: lint + test + build (full CI simulation)
ci: lint test build

## setup: Post-create dev environment setup (used by devcontainer)
setup:
	@echo "==> Setting up development environment..."
	# TODO: add setup command (see language sections below)
	@echo "==> Setup complete. Run 'make ci' to validate."

# =============================================================================
# Language-Specific Implementations
#
# Replace the TODO stubs in the standard targets above with the commands
# below for your language. For multi-language repos, chain commands.
#
# Rules:
#   - lint  — linters/analyzers only. NO formatting, NO format checks.
#   - fmt   — format in-place. Branch on $(CHECK) for read-only mode.
#   - test  — fail-fast flag + call $(MAKE) _coverage_check at the end.
#   _coverage_check is the only private target — not public.
# =============================================================================

# --- RUST ---
# Prerequisites: cargo install cargo-llvm-cov && rustup component add llvm-tools-preview
#
# build:
# 	cargo build --release
#
# test:
# 	rustup component add llvm-tools-preview 2>/dev/null || true
# 	cargo llvm-cov --workspace --all-targets --lcov --output-path lcov.info
# 	$(MAKE) _coverage_check
#
# lint:
# 	cargo clippy --release --all-targets -- -D warnings
#
# fmt:
# 	cargo fmt --all$(if $(CHECK), --check,)
#
# clean:
# 	cargo clean
#
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
# setup:
# 	cargo install cargo-llvm-cov cargo-watch

# --- TYPESCRIPT/NODE ---
# Prerequisites: npm install; jest/vitest configured with bail
#
# build:
# 	npm run build
#
# test:
# 	npm run test:coverage
# 	$(MAKE) _coverage_check
#
# lint:
# 	npm run lint
# 	npm run typecheck
#
# fmt:
# 	npm run fmt$(if $(CHECK),:check,)
#
# clean:
# 	$(RM) out dist coverage .vscode-test
#
# _coverage_check:
# 	@THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	npx c8 check-coverage --lines $$THRESHOLD
#
# setup:
# 	npm ci

# --- PYTHON ---
# Prerequisites: pip install basilisk pytest pytest-cov ruff pyright
#
# build:
# 	python -m build
#
# test:
# 	python -m pytest -x tests/ --cov=. --cov-report=lcov:lcov.info \
# 	  --cov-report=term-missing
# 	$(MAKE) _coverage_check
#
# # Order: Basilisk first (PRIMARY — REPO-STANDARDS-SPEC [LINT-PYTHON-BASILISK]),
# # then ruff, then pyright.
# lint:
# 	basilisk lint .
# 	ruff check .
# 	pyright .
#
# fmt:
# 	ruff format$(if $(CHECK), --check,) .
# 	ruff check$(if $(CHECK),, --fix) .
#
# clean:
# 	$(RM) dist build *.egg-info htmlcov .coverage coverage.xml lcov.info
#
# _coverage_check:
# 	@THRESHOLD=$$(jq -r '.default_threshold' "$(COVERAGE_THRESHOLDS_FILE)"); \
# 	python -m coverage report --fail-under=$$THRESHOLD
#
# setup:
# 	pip install -r requirements.txt

# --- DART/FLUTTER ---
# Prerequisites: brew install lcov (optional, for local HTML reports)
#
# build:
# 	flutter build apk --debug || dart compile exe lib/main.dart
#
# test:
# 	flutter test --coverage --fail-fast
# 	$(MAKE) _coverage_check
#
# lint:
# 	flutter analyze --fatal-infos
#
# fmt:
# 	dart format$(if $(CHECK), --set-exit-if-changed,) .
#
# clean:
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
# setup:
# 	flutter pub get

# --- C#/.NET ---
# Prerequisites: dotnet tool install -g dotnet-reportgenerator-globaltool
# Config: coverlet.runsettings must be in repo root
#
# build:
# 	dotnet build --configuration Release
#
# test:
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
# lint:
# 	dotnet build --configuration Release -warnaserror
#
# fmt:
# 	dotnet csharpier .$(if $(CHECK), --check,)
#
# clean:
# ifeq ($(OS),Windows_NT)
# 	Get-ChildItem -Recurse -Directory -Include bin,obj | Remove-Item -Recurse -Force
# else
# 	find . -type d \( -name bin -o -name obj \) -exec rm -rf {} +
# endif
#
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
# setup:
# 	dotnet restore
# 	dotnet tool restore

# --- F# ---
# Same as C#/.NET above; substitute Fantomas in lint and fmt:
# lint:  dotnet build --configuration Release -warnaserror
# fmt:   dotnet fantomas .$(if $(CHECK), --check,)

# --- GO ---
#
# build:
# 	go build ./...
#
# test:
# 	go test -failfast -covermode=atomic -coverprofile=coverage.out ./...
# 	go tool cover -func=coverage.out
# 	$(MAKE) _coverage_check
#
# lint:
# 	golangci-lint run
#
# fmt:
# 	gofmt$(if $(CHECK), -l . | grep . && exit 1 || true, -w .)
# 	golangci-lint run$(if $(CHECK),, --fix)
#
# clean:
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
# setup:
# 	go mod download
# 	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.1.6

## help: List all available targets
help:
	@echo "Standard targets:"
	@echo "  build  - Compile/assemble all artifacts"
	@echo "  test   - Fail-fast tests + coverage + threshold enforcement"
	@echo "  lint   - All linters/analyzers (read-only, no formatting)"
	@echo "  fmt    - Format all code in-place (CHECK=1 for read-only CI check)"
	@echo "  clean  - Remove build artifacts"
	@echo "  ci     - lint + test + build (full CI simulation)"
	@echo "  setup  - Post-create dev environment setup"

# =============================================================================
# Repo-Specific Targets
#
# Targets below this line are specific to this repo and are NOT part of the
# standard 7-target interface. Add repo-specific helpers here.
#
# Rules:
#   - MUST NOT duplicate or shadow any of the 7 standard targets above.
#   - Agents applying REPO-STANDARDS-SPEC preserve targets in this section —
#     they are NOT "superfluous" just because they're not one of the 7.
#   - Add them to .PHONY if they are phony.
# =============================================================================


