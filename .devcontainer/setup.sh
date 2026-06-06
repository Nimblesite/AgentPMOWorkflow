#!/usr/bin/env bash
set -euo pipefail

echo "==> Setting up development environment..."

# Install dependencies (Playwright browsers, npm packages) via the repo's setup target.
make setup

echo "==> Setup complete. Run 'make ci' to validate."
