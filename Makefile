# =============================================================================
# Makefile — project_status
# =============================================================================

.PHONY: build test lint fmt fmt-check clean check ci

# =============================================================================
# PRIMARY TARGETS
# =============================================================================

build:
	@echo "==> Building..."
	cd app && flutter build apk --debug

test:
	@echo "==> Testing..."
	cd app && flutter test --coverage
	@COVERAGE_FILE=app/coverage/lcov.info; \
	LH=$$(grep '^LH:' "$$COVERAGE_FILE" | awk -F: '{sum+=$$2} END{print sum}'); \
	LF=$$(grep '^LF:' "$$COVERAGE_FILE" | awk -F: '{sum+=$$2} END{print sum}'); \
	if [ -z "$$LF" ] || [ "$$LF" -eq 0 ]; then echo "No coverage data found"; exit 1; fi; \
	PCT=$$(echo "scale=1; $$LH * 100 / $$LF" | bc); \
	echo "Coverage: $${PCT}% (threshold: 80%)"; \
	PCT_INT=$$(echo "$$PCT" | awk '{printf "%d", $$1}'); \
	if [ "$$PCT_INT" -lt 80 ]; then echo "COVERAGE FAILURE: $${PCT}% is below 80%"; exit 1; fi; \
	echo "COVERAGE OK: $${PCT}% meets 80% threshold"

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
