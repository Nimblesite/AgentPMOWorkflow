/** @type {import('jest').Config} */
// Merge into your main jest.config — these are coverage-specific settings only.
//
// IMPORTANT: The numeric thresholds below are NOT the source of truth.
// `coverage-thresholds.json` at the repo root is the single source of truth
// (REPO-STANDARDS-SPEC §3.3 [COVERAGE-THRESHOLDS-JSON]). The Makefile's internal
// `_coverage_check` recipe (called from `_test`, inside `make test`) reads that
// JSON file and asserts measured >= threshold. This Jest `coverageThreshold`
// block is a belt-and-braces backup that lets `jest --coverage` fail-fast on
// its own without waiting for the Makefile's check.
//
// Keep these numbers in sync with `coverage-thresholds.json` `default_threshold`
// when you ratchet it up.
module.exports = {
  collectCoverage: true,
  coverageDirectory: "coverage",
  coverageReporters: ["json", "lcov", "text", "clover", "html"],
  coveragePathIgnorePatterns: [
    "/node_modules/",
    "/dist/",
    "/out/",
    "/__tests__/",
    "/test/",
    "\\.d\\.ts$",
  ],
  bail: 1,
  coverageThreshold: {
    global: {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
  },
};
