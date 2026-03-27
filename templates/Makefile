# =============================================================================
# Standard Makefile — {{REPO_NAME}}
# All targets are language-agnostic. Add language-specific helpers below.
# =============================================================================

.PHONY: build test lint fmt fmt-check clean check ci coverage coverage-check setup

# Detect OS for platform-specific commands
OS := $(shell uname -s)

# Coverage threshold (override in CI via env var or per-repo)
COVERAGE_THRESHOLD ?= 90

# =============================================================================
# PRIMARY TARGETS (uniform interface — do not rename)
# =============================================================================

## build: Compile/assemble all artifacts
build:
	@echo "==> Building..."
	$(MAKE) _build

## test: Run full test suite with coverage
test:
	@echo "==> Testing..."
	$(MAKE) _test

## lint: Run all linters (fails on any warning)
lint:
	@echo "==> Linting..."
	$(MAKE) _lint

## fmt: Format all code in-place
fmt:
	@echo "==> Formatting..."
	$(MAKE) _fmt

## fmt-check: Check formatting without modifying
fmt-check:
	@echo "==> Checking format..."
	$(MAKE) _fmt_check

## clean: Remove all build artifacts
clean:
	@echo "==> Cleaning..."
	$(MAKE) _clean

## check: lint + test (pre-commit)
check: lint test

## ci: lint + test + build (full CI simulation)
ci: lint test build

## coverage: Generate coverage report
coverage:
	@echo "==> Coverage report..."
	$(MAKE) _coverage

## coverage-check: Assert thresholds (exits non-zero if below)
coverage-check:
	@echo "==> Checking coverage thresholds..."
	$(MAKE) _coverage_check

## setup: Post-create dev environment setup (used by devcontainer)
setup:
	@echo "==> Setting up development environment..."
	$(MAKE) _setup
	@echo "==> Setup complete. Run 'make ci' to validate."

# =============================================================================
# LANGUAGE-SPECIFIC IMPLEMENTATIONS
# Override _build, _test, _lint, _fmt, _fmt_check, _clean, _coverage,
# _coverage_check in a language section below.
# For multi-language repos, chain them: _test: test-rust test-ts test-dotnet
# =============================================================================

# --- RUST ---
# _build:
# 	cargo build --release
#
# _test:
# 	cargo llvm-cov --all-features --lcov --output-path lcov.info
# 	$(MAKE) coverage-check
#
# _lint:
# 	cargo fmt --all --check
# 	cargo clippy --release --all-targets -- -D warnings
#
# _fmt:
# 	cargo fmt --all
#
# _fmt_check:
# 	cargo fmt --all --check
#
# _clean:
# 	cargo clean
#
# _coverage:
# 	cargo llvm-cov --all-features --html --open
#
# _coverage_check:
# 	@awk -F'[,:]' '/^DA:/{total++; if($$3>0) hit++} END{pct=(total>0)?hit/total*100:0; printf "Line coverage: %.1f%%\n",pct; if(pct<$(COVERAGE_THRESHOLD)){printf "FAIL: %.1f%% < %d%%\n",pct,$(COVERAGE_THRESHOLD); exit 1} else {printf "OK: %.1f%% >= %d%%\n",pct,$(COVERAGE_THRESHOLD)}}' lcov.info

# --- TYPESCRIPT/NODE ---
# _build:
# 	npm run build
#
# _test:
# 	npm run test:coverage
# 	$(MAKE) coverage-check
#
# _lint:
# 	npm run fmt:check
# 	npm run lint
#
# _fmt:
# 	npm run fmt
#
# _fmt_check:
# 	npm run fmt:check
#
# _clean:
# 	rm -rf out dist coverage .vscode-test
#
# _coverage:
# 	open coverage/index.html || xdg-open coverage/index.html
#
# _coverage_check:
# 	@npx c8 check-coverage --lines $(COVERAGE_THRESHOLD)

# --- PYTHON ---
# _build:
# 	python -m build
#
# _test:
# 	python -m pytest tests/ --cov=. --cov-report=lcov:lcov.info \
# 	  --cov-report=term-missing --cov-config=.coveragerc
# 	$(MAKE) coverage-check
#
# _lint:
# 	ruff format --check .
# 	ruff check .
# 	pyright .
#
# _fmt:
# 	ruff format .
# 	ruff check --fix .
#
# _fmt_check:
# 	ruff format --check .
# 	ruff check .
#
# _clean:
# 	rm -rf dist build *.egg-info htmlcov .coverage coverage.xml lcov.info
#
# _coverage:
# 	python -m pytest tests/ --cov=. --cov-report=html && open htmlcov/index.html
#
# _coverage_check:
# 	@python -m coverage report --fail-under=$(COVERAGE_THRESHOLD)

# --- DART/FLUTTER ---
# _build:
# 	flutter build apk --debug || dart compile exe lib/main.dart
#
# _test:
# 	flutter test --coverage
# 	$(MAKE) coverage-check
#
# _lint:
# 	dart format --set-exit-if-changed .
# 	flutter analyze --fatal-infos
#
# _fmt:
# 	dart format .
#
# _fmt_check:
# 	dart format --set-exit-if-changed .
#
# _clean:
# 	flutter clean || rm -rf build
#
# _coverage:
# 	genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
#
# _coverage_check:
# 	@awk -F'[,:]' '/^DA:/{total++; if($$3>0) hit++} END{pct=(total>0)?hit/total*100:0; printf "Line coverage: %.1f%%\n",pct; if(pct<$(COVERAGE_THRESHOLD)){printf "FAIL: %.1f%% < %d%%\n",pct,$(COVERAGE_THRESHOLD); exit 1} else {printf "OK: %.1f%% >= %d%%\n",pct,$(COVERAGE_THRESHOLD)}}' coverage/lcov.info

# --- C#/.NET ---
# _build:
# 	dotnet build --configuration Release
#
# _test:
# 	dotnet test --configuration Release --collect:"XPlat Code Coverage" \
# 	  --results-directory TestResults -- DataCollectionRunSettings.DataCollectors\
# 	  .DataCollector.Configuration.Format=lcov
# 	$(MAKE) coverage-check
#
# _lint:
# 	dotnet build --configuration Release -warnaserror
# 	dotnet csharpier . --check
#
# _fmt:
# 	dotnet csharpier .
#
# _fmt_check:
# 	dotnet csharpier . --check
#
# _clean:
# 	find . -type d -name bin -o -type d -name obj | xargs rm -rf
#
# _coverage:
# 	reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:coverage/html \
# 	  -reporttypes:Html && open coverage/html/index.html
#
# _coverage_check:
# 	@TOTAL_LINE=$$(dotnet test --collect:"XPlat Code Coverage" --results-directory TestResults 2>/dev/null; \
# 	  find TestResults -name 'coverage.cobertura.xml' -exec grep -oP 'line-rate="\K[^"]+' {} \; | head -1); \
# 	  PCT=$$(awk "BEGIN{printf \"%.1f\", $${TOTAL_LINE:-0}*100}"); \
# 	  echo "Line coverage: $${PCT}%"; \
# 	  awk "BEGIN{if($${PCT}+0<$(COVERAGE_THRESHOLD)+0){print \"FAIL: \" $${PCT} \"%% < $(COVERAGE_THRESHOLD)%%\"; exit 1} else {print \"OK\"}}"

# --- F# ---
# Same as C#/.NET above; add Fantomas for formatting:
# _fmt:
# 	dotnet fantomas .
# _fmt_check:
# 	dotnet fantomas . --check

# --- GO ---
# _build:
# 	go build ./...
#
# _test:
# 	go test -covermode=atomic -coverprofile=coverage.out ./...
# 	go tool cover -func=coverage.out
# 	$(MAKE) coverage-check
#
# _lint:
# 	gofmt -l . | grep . && exit 1 || true
# 	golangci-lint run
#
# _fmt:
# 	gofmt -w .
# 	golangci-lint run --fix
#
# _fmt_check:
# 	gofmt -l . | grep . && exit 1 || true
#
# _clean:
# 	go clean ./...
# 	rm -f coverage.out coverage.html
#
# _coverage:
# 	go tool cover -html=coverage.out -o coverage.html && open coverage.html
#
# _coverage_check:
# 	@go tool cover -func=coverage.out | awk '/^total:/{gsub(/%/,"",$$3); if($$3+0<$(COVERAGE_THRESHOLD)+0){printf "FAIL: %s%% < %d%%\n",$$3,$(COVERAGE_THRESHOLD); exit 1} else {printf "OK: %s%% >= %d%%\n",$$3,$(COVERAGE_THRESHOLD)}}'

# --- SETUP (devcontainer post-create) ---
# Uncomment the block(s) matching your language(s).

# _setup:  # Rust
# 	cargo install cargo-llvm-cov cargo-watch

# _setup:  # Node
# 	npm ci

# _setup:  # Python
# 	pip install -r requirements.txt

# _setup:  # Dart/Flutter
# 	flutter pub get

# _setup:  # C#/.NET
# 	dotnet restore
# 	dotnet tool restore

# _setup:  # Go
# 	go mod download
# 	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.1.6

# --- UNIVERSAL COVERAGE CHECK (auto-detect) ---
# If you prefer a single auto-detecting target instead of per-language ones,
# uncomment this block (and leave the per-language _coverage_check commented):
#
# _coverage_check:
# 	@THRESHOLD=$(COVERAGE_THRESHOLD); \
# 	if [ -f "lcov.info" ] || [ -f "coverage/lcov.info" ]; then \
# 	  FILE=$$([ -f "lcov.info" ] && echo "lcov.info" || echo "coverage/lcov.info"); \
# 	  LH=$$(grep '^LH:' "$$FILE" | awk -F: '{sum+=$$2} END{print sum}'); \
# 	  LF=$$(grep '^LF:' "$$FILE" | awk -F: '{sum+=$$2} END{print sum}'); \
# 	  [ -z "$$LF" ] || [ "$$LF" -eq 0 ] && { echo "FAIL: No lines in lcov.info"; exit 1; }; \
# 	  PCT=$$(echo "scale=1; $$LH * 100 / $$LF" | bc); \
# 	elif [ -f "coverage.out" ]; then \
# 	  PCT=$$(go tool cover -func=coverage.out | awk '/^total:/{print $$3}' | tr -d '%'); \
# 	elif [ -f "coverage/coverage-summary.json" ]; then \
# 	  PCT=$$(jq '.total.lines.pct' coverage/coverage-summary.json); \
# 	else \
# 	  echo "FAIL: No coverage file found"; exit 1; \
# 	fi; \
# 	PCT_INT=$$(echo "$$PCT" | awk '{printf "%d", $$1}'); \
# 	echo "Coverage: $${PCT}% (threshold: $${THRESHOLD}%)"; \
# 	if [ "$$PCT_INT" -lt "$$THRESHOLD" ]; then \
# 	  echo "FAIL: $${PCT}% < $${THRESHOLD}%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $${THRESHOLD}%"; \
# 	fi

# =============================================================================
# HELP
# =============================================================================
help:
	@echo "Available targets:"
	@echo "  build          - Compile/assemble all artifacts"
	@echo "  test           - Run full test suite with coverage"
	@echo "  lint           - Run all linters (errors mode)"
	@echo "  fmt            - Format all code in-place"
	@echo "  fmt-check      - Check formatting (no modification)"
	@echo "  clean          - Remove build artifacts"
	@echo "  check          - lint + test (pre-commit)"
	@echo "  ci             - lint + test + build (full CI)"
	@echo "  coverage       - Generate and open coverage report"
	@echo "  coverage-check - Assert coverage thresholds"
	@echo "  setup          - Post-create dev environment setup"
