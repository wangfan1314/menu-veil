#!/bin/zsh
set -euo pipefail

ROOT_DIR=${0:A:h:h}
APP_NAME=MenuVeil
VERSION=${MENUVEIL_VERSION:-0.1.0}
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg"
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

MENUVEIL_SIGN_IDENTITY=${MENUVEIL_SIGN_IDENTITY:--} "$ROOT_DIR/scripts/build-app.sh"
cp -R "$ROOT_DIR/dist/$APP_NAME.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

SIGN_IDENTITY=${MENUVEIL_SIGN_IDENTITY:-}
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  if [[ -n "${MENUVEIL_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$MENUVEIL_NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
  fi
fi

echo "$DMG_PATH"
