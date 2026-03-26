#!/usr/bin/env bash
set -euo pipefail

echo "==> Setting up development environment..."

# ---- Dart/Flutter ----
if command -v flutter &>/dev/null; then
  cd app && flutter pub get && cd ..
  cd cli && dart pub get && cd ..
  cd core && dart pub get && cd ..
fi

echo "==> Setup complete. Run 'make ci' to validate."
