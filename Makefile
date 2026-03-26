# =============================================================================
# Makefile — project_status
# =============================================================================

.PHONY: build test lint fmt fmt-check clean check ci coverage coverage-check

# =============================================================================
# PRIMARY TARGETS
# =============================================================================

build:
	@echo "==> Building..."
	cd app && flutter build apk --debug

test:
	@echo "==> Testing..."
	cd app && flutter test --coverage
	@scripts/check-coverage.sh

lint:
	@echo "==> Linting..."
	dart format --set-exit-if-changed .
	cd app && flutter analyze --fatal-infos
	cd cli && dart analyze --fatal-infos
	cd core && dart analyze --fatal-infos

fmt:
	@echo "==> Formatting..."
	dart format .

fmt-check:
	@echo "==> Checking format..."
	dart format --set-exit-if-changed .

clean:
	@echo "==> Cleaning..."
	cd app && flutter clean
	rm -rf coverage/

check: lint test

ci: lint test build

coverage:
	@echo "==> Coverage report..."
	cd app && flutter test --coverage
	genhtml app/coverage/lcov.info -o coverage/html && open coverage/html/index.html

coverage-check:
	@echo "==> Checking coverage thresholds..."
	@scripts/check-coverage.sh

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
