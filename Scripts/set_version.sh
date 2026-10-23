#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Использование: $0 <version> [build]" >&2
    echo "Пример: $0 1.0.1 42" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

VERSION="${1#v}"
BUILD="${2:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Версия должна быть в формате SemVer, например 1.0.1" >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Scripts/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD}" Scripts/Info.plist

echo "✓ Версия: ${VERSION} (${BUILD})"
echo "  Не забудьте обновить CHANGELOG.md."
