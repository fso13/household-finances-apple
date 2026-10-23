#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Финансы"
EXECUTABLE="Finances"
APP_DIR="dist/${APP_NAME}.app"

echo "→ Сборка (${CONFIG})…"
swift build -c "$CONFIG" --product "$EXECUTABLE"

echo "→ Сборка бандла…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/${CONFIG}/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
cp "Scripts/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -f "Assets/AppIcon.icns" ]; then
    cp "Assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc подпись, чтобы приложение запускалось без предупреждений.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || {
    echo "⚠️  Не удалось подписать приложение ad-hoc"
}

echo "✓ Готово: ${APP_DIR}"
echo "  Запуск: open \"${APP_DIR}\""
