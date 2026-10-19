#!/usr/bin/env bash
# Собирает универсальный (arm64 + x86_64) Release и упаковывает его в DMG и ZIP в dist/.
# Использование: scripts/package.sh <версия> [номер-сборки]
set -euo pipefail

VERSION="${1:?Укажите версию, например: scripts/package.sh 0.2.0}"
BUILD_NUMBER="${2:-1}"

cd "$(dirname "$0")/.."
DERIVED=build/Release
APP="$DERIVED/Build/Products/Release/MacToolbox.app"
OUT=dist

rm -rf "$OUT" "$DERIVED"
mkdir -p "$OUT"

xcodegen generate --quiet
xcodebuild \
  -project MacToolbox.xcodeproj \
  -scheme MacToolbox \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -quiet build

echo "Архитектуры: $(lipo -archs "$APP/Contents/MacOS/MacToolbox")"
codesign --verify --deep --strict "$APP"

# ZIP — ditto сохраняет атрибуты и подпись бандла.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/MacToolbox-$VERSION.zip"

# DMG с ярлыком «Программы» для перетаскивания.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Mac Toolbox $VERSION" -srcfolder "$STAGE" -ov -format UDZO \
  "$OUT/MacToolbox-$VERSION.dmg"

(cd "$OUT" && shasum -a 256 MacToolbox-* > SHA256SUMS.txt)
ls -lh "$OUT"
