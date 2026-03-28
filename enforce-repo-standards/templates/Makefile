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
# Prerequisites: cargo install cargo-llvm-cov && rustup component add llvm-tools-preview
#
# _build:
# 	cargo build --release
#
# _test:
# 	rustup component add llvm-tools-preview 2>/dev/null || true
# 	cargo llvm-cov --workspace --all-targets --lcov --output-path lcov.info
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
# 	cargo llvm-cov report --html --output-dir target/llvm-cov/html
# 	@echo "==> HTML report: target/llvm-cov/html/index.html"
#
# _coverage_check:
# 	@LH=$$(grep '^LH:' lcov.info | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	LF=$$(grep '^LF:' lcov.info | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	if [ "$$LF" -eq 0 ]; then echo "FAIL: No lines in lcov.info"; exit 1; fi; \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $$LH/$$LF*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $$LH/$$LF*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $(COVERAGE_THRESHOLD)%)"; \
# 	if [ "$$PCT_INT" -lt "$(COVERAGE_THRESHOLD)" ]; then \
# 	  echo "FAIL: $${PCT}% < $(COVERAGE_THRESHOLD)%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $(COVERAGE_THRESHOLD)%"; \
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
# 	@echo "==> HTML report: coverage/index.html"
# 	open coverage/index.html || xdg-open coverage/index.html
#
# _coverage_check:
# 	npx c8 check-coverage --lines $(COVERAGE_THRESHOLD)
#
# _setup:
# 	npm ci

# --- PYTHON ---
# Prerequisites: pip install pytest pytest-cov
#
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
# 	python -m pytest tests/ --cov=. --cov-report=html --cov-config=.coveragerc
# 	@echo "==> HTML report: htmlcov/index.html"
#
# _coverage_check:
# 	python -m coverage report --fail-under=$(COVERAGE_THRESHOLD)
#
# _setup:
# 	pip install -r requirements.txt

# --- DART/FLUTTER ---
# Prerequisites: brew install lcov (for genhtml)
#
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
# 	genhtml coverage/lcov.info -o coverage/html
# 	@echo "==> HTML report: coverage/html/index.html"
#
# _coverage_check:
# 	@LCOV_FILE="coverage/lcov.info"; \
# 	if [ ! -f "$$LCOV_FILE" ]; then echo "FAIL: $$LCOV_FILE not found"; exit 1; fi; \
# 	LH=$$(grep '^LH:' "$$LCOV_FILE" | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	LF=$$(grep '^LF:' "$$LCOV_FILE" | awk -F: '{sum+=$$2} END{print sum+0}'); \
# 	if [ "$$LF" -eq 0 ]; then echo "FAIL: No lines in lcov.info"; exit 1; fi; \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $$LH/$$LF*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $$LH/$$LF*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $(COVERAGE_THRESHOLD)%)"; \
# 	if [ "$$PCT_INT" -lt "$(COVERAGE_THRESHOLD)" ]; then \
# 	  echo "FAIL: $${PCT}% < $(COVERAGE_THRESHOLD)%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $(COVERAGE_THRESHOLD)%"; \
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
# _test:
# 	rm -rf TestResults
# 	dotnet test $$(find . -maxdepth 1 -name '*.sln' | head -1) \
# 	  --configuration Release \
# 	  --settings coverlet.runsettings \
# 	  --collect:"XPlat Code Coverage" \
# 	  --results-directory TestResults \
# 	  --verbosity normal
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
# 	reportgenerator \
# 	  -reports:"TestResults/**/coverage.cobertura.xml" \
# 	  -targetdir:coverage/html \
# 	  -reporttypes:Html
# 	@echo "==> HTML report: coverage/html/index.html"
#
# _coverage_check:
# 	@COBERTURA=$$(find TestResults -name 'coverage.cobertura.xml' | head -1); \
# 	if [ -z "$$COBERTURA" ]; then echo "FAIL: No coverage.cobertura.xml found"; exit 1; fi; \
# 	LINE_RATE=$$(grep -oP 'line-rate="\K[^"]+' "$$COBERTURA" | head -1); \
# 	PCT=$$(awk "BEGIN{printf \"%.1f\", $${LINE_RATE:-0}*100}"); \
# 	PCT_INT=$$(awk "BEGIN{printf \"%d\", $${LINE_RATE:-0}*100}"); \
# 	echo "Line coverage: $${PCT}% (threshold: $(COVERAGE_THRESHOLD)%)"; \
# 	if [ "$$PCT_INT" -lt "$(COVERAGE_THRESHOLD)" ]; then \
# 	  echo "FAIL: $${PCT}% < $(COVERAGE_THRESHOLD)%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $(COVERAGE_THRESHOLD)%"; \
# 	fi
#
# _setup:
# 	dotnet restore
# 	dotnet tool restore

# --- F# ---
# Same as C#/.NET above; add Fantomas for formatting:
# _fmt:
# 	dotnet fantomas .
# _fmt_check:
# 	dotnet fantomas . --check

# --- GO ---
#
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
# 	go tool cover -html=coverage.out -o coverage.html
# 	@echo "==> HTML report: coverage.html"
#
# _coverage_check:
# 	@PCT=$$(go tool cover -func=coverage.out | awk '/^total:/{print $$3}' | tr -d '%'); \
# 	PCT_INT=$$(echo "$$PCT" | awk '{printf "%d", $$1}'); \
# 	echo "Line coverage: $${PCT}% (threshold: $(COVERAGE_THRESHOLD)%)"; \
# 	if [ "$$PCT_INT" -lt "$(COVERAGE_THRESHOLD)" ]; then \
# 	  echo "FAIL: $${PCT}% < $(COVERAGE_THRESHOLD)%"; exit 1; \
# 	else \
# 	  echo "OK: $${PCT}% >= $(COVERAGE_THRESHOLD)%"; \
# 	fi
#
# _setup:
# 	go mod download
# 	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.1.6

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
