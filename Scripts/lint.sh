#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun не найден: установите Xcode Command Line Tools" >&2
    exit 1
fi

echo "→ swift-format lint"
xcrun swift-format lint \
    --configuration .swift-format \
    --strict \
    --recursive \
    Sources Tests

echo "✓ Форматирование в порядке"
