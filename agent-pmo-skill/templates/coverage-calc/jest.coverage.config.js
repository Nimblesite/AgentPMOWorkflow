/** @type {import('jest').Config} */
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
  // Merge into your main jest.config — these are coverage-specific settings only.
  // The coverage-check target in the Makefile uses c8 or this config's thresholds.
  coverageThreshold: {
    global: {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
  },
};
